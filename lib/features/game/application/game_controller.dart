import 'dart:async';
import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/difficulty_levels.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../engine_ffi/lc0_engine/lc0_service.dart';
import '../../../engine_ffi/stockfish_engine/stockfish_service.dart';
import '../../history/domain/game_replayer.dart';
import '../../hints/domain/hint_result.dart';
import '../../pgn/application/pgn_service.dart';
import '../../tactics/domain/tactical_analysis.dart';
import 'game_state.dart';

typedef Lc0EngineFactory = Lc0Engine Function();
typedef StockfishEngineFactory = StockfishEngine Function();
typedef MaiaWeightsResolver = Future<String> Function(DifficultyLevel level);
typedef _HintCacheKey = ({int gameGeneration, String fen, int movetimeMs});

/// Inject engine contracts and weights extraction so controller flows can be
/// tested without native FFI.
final lc0EngineFactoryProvider = Provider<Lc0EngineFactory>(
  (ref) => Lc0Service.new,
);
final stockfishEngineFactoryProvider = Provider<StockfishEngineFactory>(
  (ref) => StockfishService.new,
);
final maiaWeightsResolverProvider = Provider<MaiaWeightsResolver>(
  (ref) =>
      (level) => Lc0Service.extractWeightsAsset(level.weightsAsset),
);
final hintTotalTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 120),
);
final stockfishWarmupEnabledProvider = Provider<bool>(
  (ref) => Platform.isAndroid,
);

/// Coordinate rules, persistence, and engines. Maia selects opponent moves;
/// Stockfish calculates hints and opponent plans. Attack highlights use
/// geometric board analysis.
class GameController extends Notifier<GameState> {
  Lc0Engine? _lc0;
  int? _loadedLevelRating;
  StockfishEngine? _stockfish;
  Future<StockfishEngine>? _stockfishStartup;

  Future<HintResult>? _hintInFlight;
  ({_HintCacheKey key, HintResult result})? _cachedHint;
  ({String fen, Future<ThreatResult> future, Completer<Never> cancellation})?
  _threatInFlight;
  int _threatGeneration = 0;
  Future<void> _stockfishSearchTail = Future.value();
  ({int gameGeneration, String fen, ThreatResult result})? _cachedThreats;
  Completer<Never>? _hintCancellation;
  int _hintGeneration = 0;
  int _gameGeneration = 0;
  bool _promotionPending = false;
  bool _isDisposed = false;
  Future<void> _persistenceTail = Future.value();
  Future<void>? _engineDisposal;

  @override
  GameState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _gameGeneration++;
      _hintGeneration++;
      cancelOpponentThreats();
      final cancellation = _hintCancellation;
      if (cancellation != null && !cancellation.isCompleted) {
        cancellation.completeError(
          const HintCancelledException('Controller disposed'),
        );
      }
      unawaited(_disposeEngines());
    });
    return GameState.initial();
  }

  /// Start a local two-player game and dispose engines from any previous AI
  /// game.
  Future<void> startTwoPlayers() async {
    final generation = ++_gameGeneration;
    await _cancelHint('A new game was started.');
    if (!_isCurrentGame(generation)) return;
    await _disposeEngines();
    if (!_isCurrentGame(generation)) return;
    state = GameState.initial();
    await _beginPersistedGame();
  }

  /// Start an AI game with [humanSide] against Maia at [levelRating]
  /// (1100–1900). Load the corresponding network and play the opening move
  /// immediately when Maia is White.
  Future<bool> startVsAi({
    required Side humanSide,
    required int levelRating,
    bool campaignMode = false,
  }) async {
    DifficultyLevel.byRating(levelRating); // Validate before changing state.
    _gameGeneration++;
    final gameGeneration = _gameGeneration;
    await _cancelHint('A new game was started.');
    if (!_isCurrentGame(gameGeneration)) return false;
    if (state.aiThinking) {
      await _discardLc0();
      if (!_isCurrentGame(gameGeneration)) return false;
    }

    state = GameState.initial().copyWith(
      aiSide: humanSide.opposite,
      levelRating: levelRating,
      aiThinking: true,
      campaignMode: campaignMode,
    );
    try {
      await _ensureEngineLoaded(levelRating);
    } catch (e) {
      if (_isCurrentGame(gameGeneration)) {
        state = state.copyWith(aiThinking: false, engineError: 'Maia: $e');
      }
      return false;
    }
    if (!_isCurrentGame(gameGeneration)) return false;
    state = state.copyWith(aiThinking: false);
    if (!await _beginPersistedGame(playerSide: humanSide)) {
      return false;
    }
    if (!_isCurrentGame(gameGeneration)) return false;
    return _maybePlayAiTurn();
  }

  /// Restore the sole active autosave. Replay every UCI move and check
  /// intermediate FENs before exposing state. If only the human move was
  /// saved, Maia responds once; an already saved Maia reply is not
  /// duplicated.
  Future<bool> restoreActiveGame() async {
    _gameGeneration++;
    final generation = _gameGeneration;
    await _cancelHint('A saved game was restored.');
    if (!_isCurrentGame(generation)) return false;
    await _disposeEngines();
    if (!_isCurrentGame(generation)) return false;

    StoredGame? stored;
    try {
      await flushPersistence();
      if (!_isCurrentGame(generation)) return false;
      stored = await ref.read(gameRepositoryProvider).getActiveGame();
    } catch (error) {
      if (!_isCurrentGame(generation)) return false;
      state = GameState.initial().copyWith(
        persistenceError: 'Could not open the autosave: $error',
      );
      return false;
    }
    if (!_isCurrentGame(generation) || stored == null) return false;
    late final ReplayedGame replayed;
    try {
      replayed = const GameReplayer().replay(stored);
    } catch (error) {
      state = GameState.initial().copyWith(
        persistenceError: 'Could not restore the game: $error',
      );
      return false;
    }

    final aiSide = stored.levelRating == null
        ? null
        : stored.playerSide?.opposite;
    state = GameState(
      position: replayed.positions.last,
      positionHistory: replayed.positions
          .take(replayed.positions.length - 1)
          .toList(growable: false),
      sanHistory: stored.moves.map((move) => move.san).toList(growable: false),
      uciHistory: stored.moves.map((move) => move.uci).toList(growable: false),
      moveActorHistory: stored.moves
          .map((move) => move.actor)
          .toList(growable: false),
      moveTimeHistoryUtc: stored.moves
          .map((move) => move.playedAtUtc)
          .toList(growable: false),
      evaluated: stored.evaluated,
      aiSide: aiSide,
      levelRating: stored.levelRating,
      gameId: stored.id,
      startedAtUtc: stored.startedAtUtc,
      campaignMode: stored.campaignMode,
      clockEnabled: stored.clockEnabled,
      initialTimeMs: stored.initialTimeMs,
      whiteTimeMs: stored.whiteTimeMs,
      blackTimeMs: stored.blackTimeMs,
    );

    if (state.isGameOver) {
      await _persistCurrentGame();
      return _isCurrentGame(generation);
    }

    if (stored.levelRating != null) {
      state = state.copyWith(aiThinking: true);
      try {
        await _ensureEngineLoaded(stored.levelRating!);
      } catch (error) {
        if (_isCurrentGame(generation)) {
          state = state.copyWith(
            aiThinking: false,
            engineError: 'Maia: $error',
          );
        }
        return false;
      }
      if (!_isCurrentGame(generation)) return false;
      state = state.copyWith(aiThinking: false);
      return _maybePlayAiTurn();
    }
    return true;
  }

  /// Select, switch, or clear a piece on a tap of [square]. Play a legal
  /// destination, consulting [onPromotion] when needed. Ignore input while
  /// the AI or a promotion is active, or after game over.
  Future<void> onSquareTapped(
    Square square, {
    required Future<Role?> Function() onPromotion,
  }) async {
    if (_promotionPending ||
        state.isGameOver ||
        state.isAiTurn ||
        state.aiThinking) {
      return;
    }

    if (_hintInFlight != null) {
      final position = state.position;
      await cancelHint();
      if (_isDisposed || !identical(position, state.position)) return;
    }
    final selected = state.selectedSquare;

    if (selected == null) {
      if (_hasOwnPieceAt(square)) {
        state = state.copyWith(selectedSquare: square);
      }
      return;
    }

    if (selected == square) {
      state = state.copyWith(clearSelection: true);
      return;
    }

    final legalDestinations = state.legalDestinationsFrom(selected);
    if (!legalDestinations.contains(square)) {
      // Switch to another own piece, or clear selection on an unrelated
      // square.
      state = _hasOwnPieceAt(square)
          ? state.copyWith(selectedSquare: square)
          : state.copyWith(clearSelection: true);
      return;
    }

    final position = state.position;
    final generation = _gameGeneration;
    final promotion = state.isPromotion(selected, square)
        ? await _choosePromotion(onPromotion)
        : null;
    if (_isDisposed ||
        generation != _gameGeneration ||
        !identical(position, state.position) ||
        (state.isPromotion(selected, square) && promotion == null)) {
      return;
    }

    await _applyMove(
      NormalMove(from: selected, to: square, promotion: promotion),
      actor: GameMoveActor.player,
    );
    await _maybePlayAiTurn();
  }

  /// Select the drag origin without toggling selection. Return false when
  /// interaction is unavailable.
  bool selectForDrag(Square square) {
    if (_promotionPending ||
        state.isGameOver ||
        state.isAiTurn ||
        state.aiThinking ||
        !_hasOwnPieceAt(square)) {
      return false;
    }
    unawaited(cancelHint());
    if (state.selectedSquare != square) {
      state = state.copyWith(selectedSquare: square);
    }
    return true;
  }

  /// Attempt a drag from [from] to [to], using [onPromotion] when required.
  /// Ignore illegal moves and unavailable interaction, as in
  /// [onSquareTapped].
  Future<void> attemptDragMove(
    Square from,
    Square to, {
    required Future<Role?> Function() onPromotion,
  }) async {
    if (_promotionPending ||
        state.isGameOver ||
        state.isAiTurn ||
        state.aiThinking) {
      return;
    }
    if (_hintInFlight != null) {
      final position = state.position;
      await cancelHint();
      if (_isDisposed || !identical(position, state.position)) return;
    }
    if (!_hasOwnPieceAt(from)) return;
    if (!state.legalDestinationsFrom(from).contains(to)) return;

    final position = state.position;
    final generation = _gameGeneration;
    final promotion = state.isPromotion(from, to)
        ? await _choosePromotion(onPromotion)
        : null;
    if (_isDisposed ||
        generation != _gameGeneration ||
        !identical(position, state.position) ||
        (state.isPromotion(from, to) && promotion == null)) {
      return;
    }

    await _applyMove(
      NormalMove(from: from, to: to, promotion: promotion),
      actor: GameMoveActor.player,
    );
    await _maybePlayAiTurn();
  }

  Future<Role?> _choosePromotion(Future<Role?> Function() choose) async {
    _promotionPending = true;
    try {
      return await choose();
    } finally {
      _promotionPending = false;
    }
  }

  /// Validate and apply a move through the rules engine, including moves from
  /// native engines. Throw [PlayException] if the move is illegal in the
  /// current position.
  Future<void> _applyMove(Move move, {required GameMoveActor actor}) async {
    final (newPosition, san) = state.position.makeSan(move);
    final now = DateTime.now().toUtc();
    state = state.copyWith(
      position: newPosition as Chess,
      positionHistory: [...state.positionHistory, state.position],
      sanHistory: [...state.sanHistory, san],
      uciHistory: [...state.uciHistory, move.uci],
      moveActorHistory: [...state.moveActorHistory, actor],
      moveTimeHistoryUtc: [...state.moveTimeHistoryUtc, now],
      clearSelection: true,
      clearPersistenceError: true,
    );
    await _persistCurrentGame();
  }

  /// Undo one ply in local play, or return to the previous human decision
  /// against Maia. Mark the game unrated, excluding it from rating, streaks,
  /// and campaign progress.
  Future<void> undo() async {
    if (state.isGameOver || !state.canUndo || state.aiThinking) {
      return;
    }
    if (_hintInFlight != null) {
      final position = state.position;
      await cancelHint();
      if (_isDisposed || !identical(position, state.position)) return;
    }
    final history = [...state.positionHistory];
    final sanHistory = [...state.sanHistory];
    final uciHistory = [...state.uciHistory];
    final actorHistory = [...state.moveActorHistory];
    final timeHistory = [...state.moveTimeHistoryUtc];

    var previousPosition = history.removeLast();
    sanHistory.removeLast();
    uciHistory.removeLast();
    actorHistory.removeLast();
    timeHistory.removeLast();

    // Against Maia, keep undoing until the turn returns to the human player.
    if (state.aiSide != null) {
      while (history.isNotEmpty && previousPosition.turn == state.aiSide) {
        previousPosition = history.removeLast();
        sanHistory.removeLast();
        uciHistory.removeLast();
        actorHistory.removeLast();
        timeHistory.removeLast();
      }
    }

    state = state.copyWith(
      position: previousPosition,
      positionHistory: history,
      sanHistory: sanHistory,
      uciHistory: uciHistory,
      moveActorHistory: actorHistory,
      moveTimeHistoryUtc: timeHistory,
      clearSelection: true,
      evaluated: false,
    );
    await _persistCurrentGame();
  }

  /// Mark the game unrated without changing the board; persist the
  /// eligibility change before assistance is delivered.
  Future<void> markAsNotEvaluated() async {
    if (!state.evaluated) return;
    state = state.copyWith(evaluated: false);
    await _persistCurrentGame();
  }

  /// Calculate a legal Stockfish move for the captured request position.
  /// Assistance makes the game unrated even if the search fails.
  Future<HintResult> getHint({
    int stockfishMovetimeMs = StockfishEngine.defaultMovetimeMs,
  }) {
    final existing = _hintInFlight;
    if (existing != null) return existing;
    if (stockfishMovetimeMs <= 0) {
      return Future.error(
        ArgumentError.value(
          stockfishMovetimeMs,
          'stockfishMovetimeMs',
          'must be positive',
        ),
      );
    }

    if (_promotionPending ||
        state.aiThinking ||
        state.hintThinking ||
        state.isAiTurn ||
        state.isGameOver) {
      return Future.error(
        StateError('Hints are unavailable at this point in the game.'),
      );
    }

    // Requesting assistance changes eligibility immediately, so engine
    // failure cannot reverse the game rule.
    final evaluationPersistence = markAsNotEvaluated();

    final position = state.position;
    cancelOpponentThreats();
    final generation = ++_hintGeneration;
    final cancellation = Completer<Never>();
    _hintCancellation = cancellation;
    state = state.copyWith(hintThinking: true, clearEngineError: true);

    final calculation = _calculateHint(
      position: position,
      stockfishMovetimeMs: stockfishMovetimeMs,
      generation: generation,
      prerequisite: evaluationPersistence,
    );
    final raced = Future.any<HintResult>([calculation, cancellation.future]);
    final timeout = ref.read(hintTotalTimeoutProvider);
    late final Future<HintResult> exposed;
    exposed = raced.timeout(
      timeout,
      onTimeout: () async {
        await _abortHintAfterFailure(generation);
        throw TimeoutException(
          'The hint exceeded the total timeout of ${timeout.inSeconds}s',
        );
      },
    );
    _hintInFlight = exposed;

    // Clean up on success and failure without creating an unobserved error
    // future, as an unawaited `whenComplete` could do.
    unawaited(
      exposed.then<void>(
        (_) => _finishHint(exposed),
        onError: (Object error, StackTrace stackTrace) => _finishHint(exposed),
      ),
    );
    return exposed;
  }

  /// Analyse the captured hypothetical opponent position without blocking
  /// moves. Discard stale results and serialise Stockfish searches, including
  /// hints requested during analysis.
  Future<ThreatResult> getOpponentThreats() {
    if (_promotionPending ||
        state.aiThinking ||
        state.hintThinking ||
        state.isAiTurn ||
        state.isGameOver ||
        state.position.isCheck) {
      return Future.error(
        StateError('Analysis is unavailable in this position.'),
      );
    }
    final fen = state.position.fen;
    final pending = _threatInFlight;
    if (pending != null && pending.fen == fen) return pending.future;
    cancelOpponentThreats();
    final generation = _threatGeneration;
    final gameGeneration = _gameGeneration;
    final position = opponentThreatPosition(state.position);
    final prerequisite = markAsNotEvaluated();
    final cancellation = Completer<Never>();
    final future = Future.any<ThreatResult>([
      _calculateThreats(
        position,
        fen,
        generation,
        gameGeneration,
        prerequisite,
      ),
      cancellation.future,
    ]);
    _threatInFlight = (fen: fen, future: future, cancellation: cancellation);
    void finish() {
      if (identical(_threatInFlight?.future, future)) _threatInFlight = null;
    }

    unawaited(
      future.then<void>(
        (_) => finish(),
        onError: (Object _, StackTrace _) => finish(),
      ),
    );
    return future;
  }

  /// Cancel result delivery and queued searches. An active native search runs
  /// to its configured budget (normally one second), subject to service
  /// timeouts; avoid recreating the engine after every move.
  void cancelOpponentThreats() {
    _threatGeneration++;
    final cancellation = _threatInFlight?.cancellation;
    _threatInFlight = null;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.completeError(
        const HintCancelledException('The opponent-plan position changed.'),
      );
    }
  }

  void _ensureThreatActive(int generation, int gameGeneration, String fen) {
    if (_isDisposed ||
        generation != _threatGeneration ||
        gameGeneration != _gameGeneration ||
        state.position.fen != fen ||
        state.hintThinking ||
        state.aiThinking ||
        state.isAiTurn ||
        state.isGameOver) {
      throw const HintCancelledException('The opponent-plan position changed.');
    }
  }

  Future<ThreatResult> _calculateThreats(
    Chess position,
    String fen,
    int generation,
    int gameGeneration,
    Future<void> prerequisite,
  ) async {
    await prerequisite;
    void ensureActive() => _ensureThreatActive(generation, gameGeneration, fen);
    final result = await _queueStockfishSearch(() async {
      ensureActive();
      final cached = _cachedThreats;
      if (cached != null &&
          cached.gameGeneration == gameGeneration &&
          cached.fen == fen) {
        return cached.result;
      }
      if (position.legalMoves.values.every((moves) => moves.isEmpty)) {
        return ThreatResult(position: position, threats: const []);
      }
      StockfishEngine? engine;
      try {
        return await (() async {
          final startup = _ensureStockfishLoaded();
          engine = _stockfish;
          engine = await startup;
          ensureActive();
          final lines = await engine!.getTopMoves(position.fen);
          ensureActive();
          return ThreatResult.fromLines(position, lines);
        })().timeout(ref.read(hintTotalTimeoutProvider));
      } on HintCancelledException {
        rethrow;
      } catch (_) {
        // An analysis failure must not dispose Maia while it may be replying.
        final currentRequest =
            generation == _threatGeneration &&
            gameGeneration == _gameGeneration;
        final failedEngine = engine ?? (currentRequest ? _stockfish : null);
        if (failedEngine != null && identical(_stockfish, failedEngine)) {
          _stockfish = null;
          _stockfishStartup = null;
          await _trackEngineDisposal([failedEngine.dispose()]);
        }
        rethrow;
      }
    });
    ensureActive();
    _cachedThreats = (gameGeneration: gameGeneration, fen: fen, result: result);
    return result;
  }

  Future<T> _queueStockfishSearch<T>(Future<T> Function() search) {
    final operation = _stockfishSearchTail.then((_) => search());
    _stockfishSearchTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<HintResult> _calculateHint({
    required Chess position,
    required int stockfishMovetimeMs,
    required int generation,
    required Future<void> prerequisite,
  }) async {
    try {
      await prerequisite;
      _ensureHintActive(generation);
      final key = (
        gameGeneration: _gameGeneration,
        fen: position.fen,
        movetimeMs: stockfishMovetimeMs,
      );
      final cached = _cachedHint;
      if (cached != null && cached.key == key) {
        return cached.result;
      }

      final uci = await _calculateStockfishHint(
        position,
        stockfishMovetimeMs,
        generation,
      );
      _ensureHintActive(generation);
      final move = Move.parse(uci);
      if (move is! NormalMove) throw StateError('Invalid hint move.');
      final result = HintResult(
        fen: position.fen,
        move: move,
        stockfishSan: _sanFor(position, uci),
      );
      _cachedHint = (key: key, result: result);
      return result;
    } on HintCancelledException {
      rethrow;
    } catch (_) {
      await _abortHintAfterFailure(generation);
      rethrow;
    }
  }

  Future<String> _calculateStockfishHint(
    Chess position,
    int movetimeMs,
    int generation,
  ) async {
    final uci = await _queueStockfishSearch(() async {
      _ensureHintActive(generation);
      final engine = await _ensureStockfishLoaded();
      _ensureHintActive(generation);
      return engine.getBestMove(position.fen, movetimeMs: movetimeMs);
    });
    _ensureHintActive(generation);
    return uci;
  }

  /// Convert UCI to SAN using the position captured at request time, never
  /// the state at search completion.
  String _sanFor(Chess position, String uci) {
    final move = Move.parse(uci);
    if (move == null) {
      throw StateError('Engine returned invalid UCI: "$uci"');
    }
    try {
      final (_, san) = position.makeSan(move);
      return san;
    } on PlayException catch (error) {
      throw StateError(
        'Engine returned illegal move "$uci" for ${position.fen}: $error',
      );
    }
  }

  /// Restart from the initial position, preserving local/AI mode, level, and
  /// campaign mode.
  Future<void> reset() async {
    final generation = ++_gameGeneration;
    await _cancelHint('The game was restarted.');
    if (!_isCurrentGame(generation)) return;
    if (state.aiThinking) {
      await _discardLc0();
      if (!_isCurrentGame(generation)) return;
    }
    state = GameState.initial().copyWith(
      aiSide: state.aiSide,
      levelRating: state.levelRating,
      campaignMode: state.campaignMode,
    );
    final playerSide = state.aiSide?.opposite;
    if (!await _beginPersistedGame(playerSide: playerSide)) return;
    if (!_isCurrentGame(generation)) return;
    await _maybePlayAiTurn();
  }

  /// Retry a failed AI reply without resetting the game. The failed engine is
  /// replaced on retry; the synchronous thinking flag prevents duplicate
  /// searches from rapid taps.
  Future<void> retryAiMove() async {
    if (state.engineError == null ||
        state.aiThinking ||
        state.hintThinking ||
        !state.isAiTurn ||
        state.isGameOver) {
      return;
    }
    await _maybePlayAiTurn();
  }

  Future<bool> _maybePlayAiTurn() async {
    if (_isDisposed) return false;
    if (state.levelRating != null && !state.isGameOver) {
      unawaited(_warmUpStockfish());
    }
    if (!state.isAiTurn || state.isGameOver) return true;

    final gameGeneration = _gameGeneration;
    final fen = state.position.fen;
    state = state.copyWith(aiThinking: true, clearEngineError: true);
    try {
      final levelRating = state.levelRating!;
      await _ensureEngineLoaded(levelRating);
      if (!_isCurrentGame(gameGeneration)) return false;
      final uci = await _lc0!.getBestMove(fen, nodes: 1);
      final move = Move.parse(uci);
      if (move == null) {
        throw StateError('lc0 returned an invalid move: "$uci"');
      }
      // Check generation and FEN as well as turn, so a late reply cannot
      // affect a restarted game.
      if (_isCurrentGame(gameGeneration) &&
          state.isAiTurn &&
          state.position.fen == fen) {
        await _applyMove(move, actor: GameMoveActor.maia);
        return true;
      }
      return false;
    } catch (e) {
      if (_isCurrentGame(gameGeneration)) {
        final failedEngine = _lc0;
        _lc0 = null;
        _loadedLevelRating = null;
        await failedEngine?.dispose();
        if (!_isCurrentGame(gameGeneration)) return false;
        state = state.copyWith(engineError: 'Maia: $e');
      }
      return false;
    } finally {
      if (_isCurrentGame(gameGeneration)) {
        state = state.copyWith(aiThinking: false);
      }
    }
  }

  Future<void> _ensureEngineLoaded(int levelRating) async {
    if (_isDisposed) {
      throw const HintCancelledException('Controller disposed');
    }
    final disposal = _engineDisposal;
    if (disposal != null) await disposal;
    if (_lc0?.isReady == true && _loadedLevelRating == levelRating) return;

    final previous = _lc0;
    _lc0 = null;
    _loadedLevelRating = null;
    await previous?.dispose();
    if (_isDisposed) {
      throw const HintCancelledException('Controller disposed');
    }

    final level = DifficultyLevel.byRating(levelRating);
    final engine = ref.read(lc0EngineFactoryProvider)();
    _lc0 = engine;
    try {
      final weightsPath = await ref.read(maiaWeightsResolverProvider)(level);
      if (!identical(_lc0, engine)) {
        throw StateError('Maia engine was disposed during startup');
      }
      await engine.init(weightsPath);
      if (!identical(_lc0, engine) || !engine.isReady) {
        throw StateError('Maia engine was not ready after startup');
      }
      _loadedLevelRating = levelRating;
    } catch (_) {
      if (identical(_lc0, engine)) {
        _lc0 = null;
        _loadedLevelRating = null;
        await engine.dispose();
      }
      rethrow;
    }
  }

  /// Warm up Stockfish NNUE on Android while the player views or plays the
  /// game. An optional warmup failure does not interrupt play; the next hint
  /// retries startup.
  Future<void> _warmUpStockfish() async {
    if (!ref.read(stockfishWarmupEnabledProvider)) return;
    try {
      await _ensureStockfishLoaded();
    } on Object {
      // _initializeStockfish has already disposed the failed engine.
    }
  }

  Future<StockfishEngine> _ensureStockfishLoaded() {
    if (_isDisposed) {
      return Future.error(const HintCancelledException('Controller disposed'));
    }
    final disposal = _engineDisposal;
    if (disposal != null) {
      return disposal.then((_) => _ensureStockfishLoaded());
    }
    final pending = _stockfishStartup;
    if (pending != null) return pending;
    final engine = _stockfish ??= ref.read(stockfishEngineFactoryProvider)();
    if (engine.isReady) return Future.value(engine);

    final loading = _initializeStockfish(engine);
    _stockfishStartup = loading;
    void finish() {
      if (identical(_stockfishStartup, loading)) _stockfishStartup = null;
    }

    unawaited(
      loading.then<void>(
        (_) => finish(),
        onError: (Object error, StackTrace stackTrace) => finish(),
      ),
    );
    return loading;
  }

  Future<StockfishEngine> _initializeStockfish(StockfishEngine engine) async {
    try {
      await engine.init();
      if (!identical(_stockfish, engine) || !engine.isReady) {
        throw StateError('Stockfish was disposed during startup');
      }
      return engine;
    } catch (_) {
      if (identical(_stockfish, engine)) {
        _stockfish = null;
        await engine.dispose();
      }
      rethrow;
    }
  }

  void _ensureHintActive(int generation) {
    if (generation != _hintGeneration) {
      throw const HintCancelledException('The hint was cancelled.');
    }
  }

  void _finishHint(Future<Object> operation) {
    if (!identical(_hintInFlight, operation)) return;
    _hintInFlight = null;
    _hintCancellation = null;
    if (!_isDisposed && state.hintThinking) {
      state = state.copyWith(hintThinking: false);
    }
  }

  /// Cancel a pending hint on interaction, screen exit, or app suspension.
  Future<void> cancelHint() => _hintInFlight == null
      ? Future.value()
      : _cancelHint('The hint was cancelled.');

  Future<void> _cancelHint(String reason) async {
    cancelOpponentThreats();
    if (_hintInFlight == null) return;
    _hintGeneration++;
    final cancellation = _hintCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.completeError(HintCancelledException(reason));
    }
    await _discardStockfish();
  }

  Future<void> _abortHintAfterFailure(int generation) async {
    if (generation != _hintGeneration) return;
    _hintGeneration++;
    await _discardStockfish();
  }

  Future<void> _discardStockfish() {
    final engine = _stockfish;
    _stockfish = null;
    _stockfishStartup = null;
    _stockfishSearchTail = Future.value();
    _cachedHint = null;
    _cachedThreats = null;
    return _trackEngineDisposal([if (engine != null) engine.dispose()]);
  }

  Future<void> _disposeEngines() {
    final lc0 = _lc0;
    final stockfish = _stockfish;
    _lc0 = null;
    _stockfish = null;
    _stockfishStartup = null;
    _loadedLevelRating = null;
    _cachedHint = null;
    _cachedThreats = null;
    return _trackEngineDisposal([
      if (lc0 != null) lc0.dispose(),
      if (stockfish != null) stockfish.dispose(),
    ]);
  }

  Future<void> _trackEngineDisposal(List<Future<void>> operations) {
    final previous = _engineDisposal;
    if (operations.isEmpty) return previous ?? Future.value();
    late final Future<void> disposal;
    disposal = Future.wait<void>([?previous, ...operations])
        .then<void>((_) {})
        .whenComplete(() {
          if (identical(_engineDisposal, disposal)) _engineDisposal = null;
        });
    _engineDisposal = disposal;
    return disposal;
  }

  Future<void> _discardLc0() async {
    final lc0 = _lc0;
    _lc0 = null;
    _loadedLevelRating = null;
    await lc0?.dispose();
  }

  Future<bool> _beginPersistedGame({Side? playerSide}) async {
    if (_isDisposed) return false;
    final generation = _gameGeneration;
    final id = ref.read(gameIdFactoryProvider)();
    final now = DateTime.now().toUtc();
    state = state.copyWith(
      gameId: id,
      startedAtUtc: now,
      clearPersistenceError: true,
    );
    final snapshot = _snapshot(
      state,
      status: StoredGameStatus.ongoing,
      result: StoredGameResult.ongoing,
    );
    try {
      await _queuePersistence(
        () => !_isCurrentGame(generation)
            ? Future.value()
            : ref
                  .read(gameRepositoryProvider)
                  .beginGame(
                    StoredGame(
                      id: snapshot.id,
                      startedAtUtc: snapshot.startedAtUtc,
                      lastModifiedAtUtc: snapshot.lastModifiedAtUtc,
                      status: snapshot.status,
                      levelRating: snapshot.levelRating,
                      playerSide: playerSide,
                      result: snapshot.result,
                      evaluated: snapshot.evaluated,
                      campaignMode: snapshot.campaignMode,
                      initialFen: snapshot.initialFen,
                      currentFen: snapshot.currentFen,
                      pgn: snapshot.pgn,
                      clockEnabled: snapshot.clockEnabled,
                      initialTimeMs: snapshot.initialTimeMs,
                      whiteTimeMs: snapshot.whiteTimeMs,
                      blackTimeMs: snapshot.blackTimeMs,
                      moves: snapshot.moves,
                    ),
                  ),
      );
      return _isCurrentGame(generation) && state.gameId == id;
    } catch (error) {
      if (!_isDisposed && state.gameId == id) {
        state = state.copyWith(
          clearGameId: true,
          persistenceError: 'Could not start autosave: $error',
        );
      }
      return false;
    }
  }

  Future<void> _persistCurrentGame() async {
    if (state.gameId == null || state.startedAtUtc == null) return;
    final snapshotState = state;
    final completed = snapshotState.isGameOver;
    var snapshot = _snapshot(
      snapshotState,
      status: completed ? StoredGameStatus.completed : StoredGameStatus.ongoing,
      result: completed
          ? _storedResult(snapshotState.result)
          : StoredGameResult.ongoing,
      termination: completed ? _termination(snapshotState) : null,
    );
    final pgn = const PgnService().export(snapshot);
    snapshot = snapshot.copyWith(pgn: pgn);

    try {
      await _queuePersistence(() {
        final repository = ref.read(gameRepositoryProvider);
        return completed
            ? repository.completeGame(snapshot).then<void>((_) {})
            : repository.saveOngoing(snapshot);
      });
      if (!_isDisposed &&
          state.gameId == snapshot.id &&
          state.persistenceError != null) {
        state = state.copyWith(clearPersistenceError: true);
      }
    } catch (error) {
      if (!_isDisposed && state.gameId == snapshot.id) {
        state = state.copyWith(persistenceError: 'Autosave failed: $error');
      }
    }
  }

  StoredGame _snapshot(
    GameState snapshotState, {
    required StoredGameStatus status,
    required StoredGameResult result,
    GameTermination? termination,
  }) {
    final id = snapshotState.gameId;
    final startedAt = snapshotState.startedAtUtc;
    if (id == null || startedAt == null) {
      throw StateError('The game does not yet have a persistent ID.');
    }
    final now = DateTime.now().toUtc();
    final moves = <StoredGameMove>[];
    for (var index = 0; index < snapshotState.sanHistory.length; index++) {
      final fenAfter = index + 1 < snapshotState.positionHistory.length
          ? snapshotState.positionHistory[index + 1].fen
          : snapshotState.position.fen;
      moves.add(
        StoredGameMove(
          ply: index + 1,
          uci: snapshotState.uciHistory[index],
          san: snapshotState.sanHistory[index],
          fenAfter: fenAfter,
          actor: snapshotState.moveActorHistory[index],
          playedAtUtc: snapshotState.moveTimeHistoryUtc[index].toUtc(),
        ),
      );
    }
    return StoredGame(
      id: id,
      startedAtUtc: startedAt.toUtc(),
      endedAtUtc: status == StoredGameStatus.completed ? now : null,
      lastModifiedAtUtc: now,
      status: status,
      levelRating: snapshotState.levelRating,
      playerSide: snapshotState.aiSide?.opposite,
      result: result,
      termination: termination,
      evaluated: snapshotState.evaluated,
      campaignMode: snapshotState.campaignMode,
      initialFen: snapshotState.positionHistory.isEmpty
          ? snapshotState.position.fen
          : snapshotState.positionHistory.first.fen,
      currentFen: snapshotState.position.fen,
      clockEnabled: snapshotState.clockEnabled,
      initialTimeMs: snapshotState.initialTimeMs,
      whiteTimeMs: snapshotState.whiteTimeMs,
      blackTimeMs: snapshotState.blackTimeMs,
      moves: List.unmodifiable(moves),
    );
  }

  Future<void> _queuePersistence(Future<void> Function() action) {
    final operation = _persistenceTail.then(
      (_) => action(),
      onError: (Object _, StackTrace stackTrace) => action(),
    );
    _persistenceTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return operation;
  }

  StoredGameResult _storedResult(GameResult result) => switch (result) {
    GameResult.emAndamento => StoredGameResult.ongoing,
    GameResult.vitoriaBrancas => StoredGameResult.whiteWin,
    GameResult.vitoriaPretas => StoredGameResult.blackWin,
    GameResult.empate => StoredGameResult.draw,
  };

  GameTermination _termination(GameState game) =>
      game.termination ?? GameTermination.unknown;

  /// Explicitly persist the current state; per-move autosave remains active.
  Future<void> saveGame() async {
    state = state.copyWith(clearPersistenceError: true);
    if (state.gameId == null &&
        !await _beginPersistedGame(playerSide: state.aiSide?.opposite)) {
      return;
    }
    await _persistCurrentGame();
  }

  /// Wait for queued writes, for tests and flows requiring deterministic
  /// durability.
  Future<void> flushPersistence() => _persistenceTail;

  /// Await cancellation and engine cleanup for integration tests and other
  /// flows using the native singletons. Service shutdown timeouts still
  /// apply.
  Future<void> shutdownEngines() async {
    _gameGeneration++;
    await _cancelHint('The engines were shut down.');
    await _disposeEngines();
  }

  bool _hasOwnPieceAt(Square square) {
    final piece = state.position.board.pieceAt(square);
    return piece != null && piece.color == state.position.turn;
  }

  bool _isCurrentGame(int generation) =>
      !_isDisposed && generation == _gameGeneration;
}

class HintCancelledException implements Exception {
  const HintCancelledException(this.message);

  final String message;

  @override
  String toString() => 'HintCancelledException: $message';
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);
