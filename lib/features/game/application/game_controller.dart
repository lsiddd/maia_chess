import 'dart:async';

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
import 'game_state.dart';

typedef Lc0EngineFactory = Lc0Engine Function();
typedef StockfishEngineFactory = StockfishEngine Function();
typedef MaiaWeightsResolver = Future<String> Function(DifficultyLevel level);

/// Pontos de injeção mantidos pequenos e orientados a contrato. Além de
/// tornarem os fluxos nativos testáveis sem FFI, evitam que o controller
/// conheça detalhes de extração de assets e construção dos motores.
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

/// Controlador da partida em andamento.
///
/// Fase 1: regras + interação local (dois jogadores humanos no mesmo
/// aparelho). Fase 2: o mesmo controller também comanda uma partida contra
/// a IA (lc0 + pesos Maia) — `_applyMove` é o único ponto de entrada para
/// aplicar um lance no tabuleiro, seja ele humano ou vindo do motor. Fase 3:
/// [getHint] usa o mesmo lc0 já carregado (o pacote só permite uma
/// instância por vez, então a lógica de dica não pode viver num serviço
/// separado com seu próprio motor) mais um Stockfish à parte.
class GameController extends Notifier<GameState> {
  Lc0Engine? _lc0;
  int? _loadedLevelRating;
  StockfishEngine? _stockfish;

  Future<HintResult>? _hintInFlight;
  Completer<HintResult>? _hintCancellation;
  int _hintGeneration = 0;
  int _gameGeneration = 0;
  bool _promotionPending = false;
  bool _isDisposed = false;
  Future<void> _persistenceTail = Future.value();

  @override
  GameState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _hintGeneration++;
      final cancellation = _hintCancellation;
      if (cancellation != null && !cancellation.isCompleted) {
        cancellation.completeError(
          const HintCancelledException('Controller descartado'),
        );
      }
      unawaited(_disposeEngines());
    });
    return GameState.initial();
  }

  /// Inicia uma partida local entre dois jogadores humanos, descartando
  /// qualquer modo vs. IA anterior (os motores não ficam mais ativos).
  Future<void> startTwoPlayers() async {
    _gameGeneration++;
    await _cancelHint('Uma nova partida foi iniciada.');
    await _disposeEngines();
    state = GameState.initial();
    await _beginPersistedGame();
  }

  /// Inicia uma partida contra a IA: [humanSide] é o lado do jogador
  /// humano, o lado oposto é jogado pelo Maia no nível [levelRating]
  /// (1100-1900). Carrega o peso correspondente no lc0; se o lado da IA
  /// jogar primeiro (IA de brancas), já dispara o primeiro lance.
  Future<bool> startVsAi({
    required Side humanSide,
    required int levelRating,
    bool campaignMode = false,
  }) async {
    DifficultyLevel.byRating(levelRating); // valida antes de alterar o estado
    _gameGeneration++;
    final gameGeneration = _gameGeneration;
    await _cancelHint('Uma nova partida foi iniciada.');
    if (state.aiThinking) {
      await _discardLc0();
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
      if (gameGeneration == _gameGeneration) {
        state = state.copyWith(aiThinking: false, engineError: 'Maia: $e');
      }
      return false;
    }
    if (gameGeneration != _gameGeneration) return false;
    state = state.copyWith(aiThinking: false);
    if (!await _beginPersistedGame(playerSide: humanSide)) {
      return false;
    }
    return _maybePlayAiTurn();
  }

  /// Restaura o único autosave ativo. Cada UCI é reaplicado pela camada de
  /// regras e cada FEN intermediária é conferida antes de expor o estado.
  /// Se o processo caiu depois do lance humano, a IA responde uma vez; se o
  /// lance da IA já estava salvo, a vez é humana e nenhum lance é duplicado.
  Future<bool> restoreActiveGame() async {
    _gameGeneration++;
    final generation = _gameGeneration;
    await _cancelHint('Uma partida salva foi restaurada.');
    await _disposeEngines();

    StoredGame? stored;
    try {
      stored = await ref.read(gameRepositoryProvider).getActiveGame();
    } catch (error) {
      state = GameState.initial().copyWith(
        persistenceError: 'Não foi possível abrir o autosave: $error',
      );
      return false;
    }
    if (stored == null) return false;
    late final ReplayedGame replayed;
    try {
      replayed = const GameReplayer().replay(stored);
    } catch (error) {
      state = GameState.initial().copyWith(
        persistenceError: 'Não foi possível restaurar a partida: $error',
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

    if (stored.levelRating != null) {
      state = state.copyWith(aiThinking: true);
      try {
        await _ensureEngineLoaded(stored.levelRating!);
      } catch (error) {
        if (generation == _gameGeneration) {
          state = state.copyWith(
            aiThinking: false,
            engineError: 'Maia: $error',
          );
        }
        return false;
      }
      if (generation != _gameGeneration) return false;
      state = state.copyWith(aiThinking: false);
      return _maybePlayAiTurn();
    }
    return true;
  }

  /// Lida com um toque na casa [square]: se nada estava selecionado e há
  /// uma peça do lado a mover ali, seleciona. Se já havia uma seleção e
  /// [square] é um destino legal, joga o lance (chamando [onPromotion] para
  /// perguntar a peça de promoção, se necessário). Caso contrário, troca ou
  /// limpa a seleção. Ignorado se for a vez da IA jogar.
  Future<void> onSquareTapped(
    Square square, {
    required Future<Role?> Function() onPromotion,
  }) async {
    if (_promotionPending ||
        state.isGameOver ||
        state.isAiTurn ||
        state.aiThinking ||
        state.hintThinking) {
      return;
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
      // Toque em outra casa: troca a seleção se houver peça própria ali,
      // senão limpa.
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

  /// Seleciona a peça ao iniciar um arraste, sem alternar a seleção como
  /// um toque faria. Retorna falso quando a interação não está disponível.
  bool selectForDrag(Square square) {
    if (_promotionPending ||
        state.isGameOver ||
        state.isAiTurn ||
        state.aiThinking ||
        state.hintThinking ||
        !_hasOwnPieceAt(square)) {
      return false;
    }
    if (state.selectedSquare != square) {
      state = state.copyWith(selectedSquare: square);
    }
    return true;
  }

  /// Tenta jogar o lance de [from] para [to] vindo do gesto de arrastar
  /// (drag-and-drop) uma peça — alternativa ao fluxo de toque em
  /// [onSquareTapped]. Ignora silenciosamente se o lance não for legal ou
  /// se for a vez da IA jogar.
  Future<void> attemptDragMove(
    Square from,
    Square to, {
    required Future<Role?> Function() onPromotion,
  }) async {
    if (_promotionPending ||
        state.isGameOver ||
        state.isAiTurn ||
        state.aiThinking ||
        state.hintThinking) {
      return;
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

  /// Aplica um lance já validado externamente (ex: sugestão de um motor
  /// FFI). Lança [PlayException] se o lance não for legal na posição
  /// atual — a validação final do lance sempre passa por esta camada de
  /// regras, mesmo quando a origem é um motor nativo (ver seção 4.3 da
  /// especificação).
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

  /// Desfaz o(s) último(s) lance(s). Numa partida contra a IA, desfaz o
  /// lance da IA e o lance humano anterior juntos, para que a vez volte a
  /// ser do jogador. Marca a partida como "não avaliada" (seção 5 e 7 da
  /// especificação: undo/dica tiram a partida do cálculo de
  /// rating/streaks).
  Future<void> undo() async {
    if (state.isGameOver ||
        !state.canUndo ||
        state.aiThinking ||
        state.hintThinking) {
      return;
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

    // Contra a IA: continua desfazendo até a vez voltar a ser do jogador
    // humano (normalmente mais um lance, o da IA que acabou de responder).
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

  /// Marca a partida como "não avaliada" sem alterar o tabuleiro — usado
  /// pelo fluxo de dica (Fase 3), que consulta o motor mas não desfaz nada.
  Future<void> markAsNotEvaluated() async {
    if (!state.evaluated) return;
    state = state.copyWith(evaluated: false);
    await _persistCurrentGame();
  }

  /// Pede a dica dupla (seção 5 da especificação): o lance que o Maia do
  /// nível atual jogaria na posição de agora, lado a lado com o lance
  /// objetivamente melhor segundo o Stockfish. Só faz sentido numa partida
  /// contra a IA (depende de um nível definido) e usá-la marca a partida
  /// como "não avaliada", mesmo que o jogador não jogue o lance sugerido.
  Future<HintResult> getHint({int stockfishMovetimeMs = 1500}) {
    final existing = _hintInFlight;
    if (existing != null) return existing;
    if (stockfishMovetimeMs <= 0) {
      return Future.error(
        ArgumentError.value(
          stockfishMovetimeMs,
          'stockfishMovetimeMs',
          'deve ser positivo',
        ),
      );
    }

    final levelRating = state.levelRating;
    if (levelRating == null) {
      return Future.error(
        StateError('Dica só está disponível numa partida contra a IA.'),
      );
    }
    if (state.aiThinking || state.isAiTurn || state.isGameOver) {
      return Future.error(
        StateError('Dica indisponível neste momento da partida.'),
      );
    }

    // Solicitar a dica já torna a partida não avaliada, mesmo se algum motor
    // falhar depois. Isso evita que uma falha técnica reverta a regra do jogo.
    final evaluationPersistence = markAsNotEvaluated();

    final position = state.position;
    final generation = ++_hintGeneration;
    final cancellation = Completer<HintResult>();
    _hintCancellation = cancellation;
    state = state.copyWith(hintThinking: true, clearEngineError: true);

    final calculation = _calculateHint(
      levelRating: levelRating,
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
          'A dica excedeu o limite total de ${timeout.inSeconds}s',
        );
      },
    );
    _hintInFlight = exposed;

    // A limpeza deve acontecer para sucesso e erro, sem criar um Future de
    // erro órfão (um risco comum ao usar `whenComplete` sem aguardar).
    unawaited(
      exposed.then<void>(
        (_) => _finishHint(exposed),
        onError: (Object error, StackTrace stackTrace) => _finishHint(exposed),
      ),
    );
    return exposed;
  }

  Future<HintResult> _calculateHint({
    required int levelRating,
    required Chess position,
    required int stockfishMovetimeMs,
    required int generation,
    required Future<void> prerequisite,
  }) async {
    try {
      await prerequisite;
      final fen = position.fen;
      await _ensureEngineLoaded(levelRating);
      _ensureHintActive(generation);
      final maiaUci = await _lc0!.getBestMove(fen, nodes: 1);
      _ensureHintActive(generation);

      _stockfish ??= ref.read(stockfishEngineFactoryProvider)();
      if (!_stockfish!.isReady) {
        await _stockfish!.init();
      }
      _ensureHintActive(generation);
      final stockfishUci = await _stockfish!.getBestMove(
        fen,
        movetimeMs: stockfishMovetimeMs,
      );
      _ensureHintActive(generation);

      return HintResult(
        levelRating: levelRating,
        maiaSan: _sanFor(position, maiaUci),
        stockfishSan: _sanFor(position, stockfishUci),
      );
    } on HintCancelledException {
      rethrow;
    } catch (_) {
      await _abortHintAfterFailure(generation);
      rethrow;
    }
  }

  /// Converte um lance em UCI para SAN usando exatamente a posição congelada
  /// no início da solicitação, nunca o estado mutável do fim do cálculo.
  String _sanFor(Chess position, String uci) {
    final move = Move.parse(uci);
    if (move == null) {
      throw StateError('Motor devolveu UCI inválido: "$uci"');
    }
    try {
      final (_, san) = position.makeSan(move);
      return san;
    } on PlayException catch (error) {
      throw StateError(
        'Motor devolveu lance ilegal "$uci" para ${position.fen}: $error',
      );
    }
  }

  /// Reinicia a partida para a posição inicial, preservando o modo atual
  /// (dois jogadores ou vs. IA, com o mesmo nível).
  Future<void> reset() async {
    _gameGeneration++;
    await _cancelHint('A partida foi reiniciada.');
    if (state.aiThinking) {
      await _discardLc0();
    }
    state = GameState.initial().copyWith(
      aiSide: state.aiSide,
      levelRating: state.levelRating,
      campaignMode: state.campaignMode,
    );
    final playerSide = state.aiSide?.opposite;
    if (!await _beginPersistedGame(playerSide: playerSide)) return;
    await _maybePlayAiTurn();
  }

  /// Repete uma resposta que falhou na posição atual, preservando a partida.
  /// O caminho da busca descarta o motor com falha e carrega outro ao tentar
  /// novamente. O bloqueio síncrono evita buscas duplicadas por toques rápidos.
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
    if (!state.isAiTurn || state.isGameOver) return true;

    final gameGeneration = _gameGeneration;
    final fen = state.position.fen;
    state = state.copyWith(aiThinking: true, clearEngineError: true);
    try {
      final levelRating = state.levelRating!;
      await _ensureEngineLoaded(levelRating);
      if (gameGeneration != _gameGeneration) return false;
      final uci = await _lc0!.getBestMove(fen, nodes: 1);
      final move = Move.parse(uci);
      if (move == null) {
        throw StateError('lc0 devolveu um lance inválido: "$uci"');
      }
      // Além do modo/turno, confere a geração e a FEN para uma resposta
      // atrasada jamais cair numa partida reiniciada.
      if (gameGeneration == _gameGeneration &&
          state.isAiTurn &&
          state.position.fen == fen) {
        await _applyMove(move, actor: GameMoveActor.maia);
        return true;
      }
      return false;
    } catch (e) {
      if (gameGeneration == _gameGeneration) {
        final failedEngine = _lc0;
        _lc0 = null;
        _loadedLevelRating = null;
        await failedEngine?.dispose();
        state = state.copyWith(engineError: 'Maia: $e');
      }
      return false;
    } finally {
      if (gameGeneration == _gameGeneration) {
        state = state.copyWith(aiThinking: false);
      }
    }
  }

  Future<void> _ensureEngineLoaded(int levelRating) async {
    if (_lc0?.isReady == true && _loadedLevelRating == levelRating) return;

    final previous = _lc0;
    _lc0 = null;
    _loadedLevelRating = null;
    await previous?.dispose();

    final level = DifficultyLevel.byRating(levelRating);
    final engine = ref.read(lc0EngineFactoryProvider)();
    _lc0 = engine;
    try {
      final weightsPath = await ref.read(maiaWeightsResolverProvider)(level);
      if (!identical(_lc0, engine)) {
        throw StateError('Motor Maia foi descartado durante a inicialização');
      }
      await engine.init(weightsPath);
      if (!identical(_lc0, engine) || !engine.isReady) {
        throw StateError('Motor Maia não ficou pronto após a inicialização');
      }
      _loadedLevelRating = levelRating;
    } catch (_) {
      if (identical(_lc0, engine)) {
        _lc0 = null;
        _loadedLevelRating = null;
      }
      await engine.dispose();
      rethrow;
    }
  }

  void _ensureHintActive(int generation) {
    if (generation != _hintGeneration) {
      throw const HintCancelledException('A dica foi cancelada.');
    }
  }

  void _finishHint(Future<HintResult> operation) {
    if (!identical(_hintInFlight, operation)) return;
    _hintInFlight = null;
    _hintCancellation = null;
    if (!_isDisposed && state.hintThinking) {
      state = state.copyWith(hintThinking: false);
    }
  }

  Future<void> _cancelHint(String reason) async {
    if (_hintInFlight == null) return;
    _hintGeneration++;
    final cancellation = _hintCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.completeError(HintCancelledException(reason));
    }
    await _disposeEngines();
  }

  Future<void> _abortHintAfterFailure(int generation) async {
    if (generation != _hintGeneration) return;
    _hintGeneration++;
    await _disposeEngines();
  }

  Future<void> _disposeEngines() async {
    final lc0 = _lc0;
    final stockfish = _stockfish;
    _lc0 = null;
    _stockfish = null;
    _loadedLevelRating = null;
    await Future.wait([
      if (lc0 != null) lc0.dispose(),
      if (stockfish != null) stockfish.dispose(),
    ]);
  }

  Future<void> _discardLc0() async {
    final lc0 = _lc0;
    _lc0 = null;
    _loadedLevelRating = null;
    await lc0?.dispose();
  }

  Future<bool> _beginPersistedGame({Side? playerSide}) async {
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
        () => ref
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
      return true;
    } catch (error) {
      if (!_isDisposed && state.gameId == id) {
        state = state.copyWith(
          clearGameId: true,
          persistenceError: 'Não foi possível iniciar o autosave: $error',
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
    } catch (error) {
      if (!_isDisposed && state.gameId == snapshot.id) {
        state = state.copyWith(persistenceError: 'Falha no autosave: $error');
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
      throw StateError('A partida ainda não possui identidade persistente.');
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
      initialFen: Chess.initial.fen,
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

  /// Aguarda gravações pendentes; usado por testes e pelo encerramento
  /// controlado de fluxos que precisam de durabilidade determinística.
  Future<void> flushPersistence() => _persistenceTail;

  /// Encerramento determinístico para testes de integração e outros fluxos
  /// que precisam aguardar a liberação dos singletons FFI.
  Future<void> shutdownEngines() async {
    _gameGeneration++;
    await _cancelHint('Os motores foram encerrados.');
    await _disposeEngines();
  }

  bool _hasOwnPieceAt(Square square) {
    final piece = state.position.board.pieceAt(square);
    return piece != null && piece.color == state.position.turn;
  }
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
