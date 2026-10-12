import 'package:dartchess/dartchess.dart';

import '../../../data/repositories/game_repository.dart';

/// Game result by winning side. Player-relative outcomes are derived
/// separately from the chosen side. Legacy enum names are retained for
/// compatibility.
enum GameResult { emAndamento, vitoriaBrancas, vitoriaPretas, empate }

/// Immutable live game state, including terminal positions.
///
/// [position] supplies rules through `dartchess`; [positionHistory] supports
/// undo and [sanHistory] supplies move notation.
///
/// [aiSide] is null in local two-player games, otherwise it identifies Maia.
/// The human plays the opposite side.
class GameState {
  GameState({
    required this.position,
    required List<Chess> positionHistory,
    required List<String> sanHistory,
    required List<String> uciHistory,
    required List<GameMoveActor> moveActorHistory,
    required List<DateTime> moveTimeHistoryUtc,
    this.selectedSquare,
    this.evaluated = true,
    this.aiSide,
    this.levelRating,
    this.aiThinking = false,
    this.hintThinking = false,
    this.engineError,
    this.persistenceError,
    this.gameId,
    this.startedAtUtc,
    this.campaignMode = false,
    this.clockEnabled = false,
    this.initialTimeMs,
    this.whiteTimeMs,
    this.blackTimeMs,
  }) : positionHistory = List.unmodifiable(positionHistory),
       sanHistory = List.unmodifiable(sanHistory),
       uciHistory = List.unmodifiable(uciHistory),
       moveActorHistory = List.unmodifiable(moveActorHistory),
       moveTimeHistoryUtc = List.unmodifiable(moveTimeHistoryUtc) {
    _validateHistory();
  }

  // Only copyWith calls this constructor, with immutable snapshots or lists
  // already owned by another GameState. Public inputs are always copied.
  GameState._({
    required this.position,
    required this.positionHistory,
    required this.sanHistory,
    required this.uciHistory,
    required this.moveActorHistory,
    required this.moveTimeHistoryUtc,
    this.selectedSquare,
    this.evaluated = true,
    this.aiSide,
    this.levelRating,
    this.aiThinking = false,
    this.hintThinking = false,
    this.engineError,
    this.persistenceError,
    this.gameId,
    this.startedAtUtc,
    this.campaignMode = false,
    this.clockEnabled = false,
    this.initialTimeMs,
    this.whiteTimeMs,
    this.blackTimeMs,
  }) {
    _validateHistory();
  }

  void _validateHistory() {
    final length = sanHistory.length;
    if (positionHistory.length != length ||
        uciHistory.length != length ||
        moveActorHistory.length != length ||
        moveTimeHistoryUtc.length != length) {
      throw ArgumentError('All game histories must have the same length.');
    }
  }

  factory GameState.initial() => GameState(
    position: Chess.initial,
    positionHistory: const [],
    sanHistory: const [],
    uciHistory: const [],
    moveActorHistory: const [],
    moveTimeHistoryUtc: const [],
  );

  final Chess position;

  /// Previous positions, one per played ply in chronological order, for undo.
  final List<Chess> positionHistory;

  /// SAN notation for each played move, such as `Nf3`, `e4`, or `O-O`.
  final List<String> sanHistory;

  /// Canonical UCI moves used to reconstruct the game.
  final List<String> uciHistory;

  /// Actor for each move, aligned with the other histories.
  final List<GameMoveActor> moveActorHistory;

  /// UTC timestamp for each move, aligned with the other histories.
  final List<DateTime> moveTimeHistoryUtc;

  /// Selected origin in the tap-to-move flow, or null when nothing is
  /// selected.
  final Square? selectedSquare;

  /// False after assistance or undo. The game stays in the library but is
  /// excluded from rating, streaks, and campaign progress.
  final bool evaluated;

  /// Side played by Maia via lc0, or null in local two-player games.
  final Side? aiSide;

  /// Maia level (1100–1900), or null outside AI play.
  final int? levelRating;

  /// True while Maia calculates its next move; disables human moves and
  /// drives the progress indicator.
  final bool aiThinking;

  /// True while calculating a hint. Board interaction cancels the pending
  /// hint; the result is validated against the captured request position.
  final bool hintThinking;

  /// Engine error, such as a weights-loading failure, or null.
  final String? engineError;

  /// Autosave failure, kept separate from engine errors so the UI identifies
  /// the affected subsystem.
  final String? persistenceError;

  /// Autosave identity, mode, and stored clock metadata. Clock fields do not
  /// imply a running game timer.
  final String? gameId;
  final DateTime? startedAtUtc;
  final bool campaignMode;
  final bool clockEnabled;
  final int? initialTimeMs;
  final int? whiteTimeMs;
  final int? blackTimeMs;

  /// The rules library handles mate, stalemate, and insufficient material.
  /// This state additionally adjudicates the fifty-move rule and threefold
  /// repetition using game history.
  bool get isDrawByFiftyMoveRule => position.halfmoves >= 100;

  // Memoization is internal: every public field remains immutable. These
  // facts depend only on the position and position history, never selection.
  bool? _threefoldRepetition;
  bool? _gameOver;

  bool get isDrawByThreefoldRepetition =>
      _threefoldRepetition ??= _hasThreefoldRepetition();

  bool _hasThreefoldRepetition() {
    final currentKey = _repetitionKey(position);
    var occurrences = 1; // The current position is not in positionHistory.
    for (final previous in positionHistory) {
      if (_repetitionKey(previous) == currentKey) {
        occurrences++;
        if (occurrences >= 3) return true;
      }
    }
    return false;
  }

  bool get isGameOver => _gameOver ??=
      position.isGameOver ||
      isDrawByFiftyMoveRule ||
      isDrawByThreefoldRepetition;

  bool get canUndo {
    if (positionHistory.isEmpty) return false;
    if (aiSide == null) return true;

    // If Maia opened as White and the human has not moved, there is no human
    // decision to undo. Reverting the opening alone would leave the AI turn
    // without triggering a reply.
    var index = positionHistory.length - 1;
    var previous = positionHistory[index];
    while (previous.turn == aiSide) {
      index--;
      if (index < 0) return false;
      previous = positionHistory[index];
    }
    return true;
  }

  /// Whether the side to move is Maia, which blocks human moves.
  bool get isAiTurn => aiSide != null && position.turn == aiSide;

  GameResult get result {
    if (!isGameOver) return GameResult.emAndamento;
    if (position.isCheckmate) {
      return position.turn == Side.white
          ? GameResult.vitoriaPretas
          : GameResult.vitoriaBrancas;
    }
    if (isDrawByFiftyMoveRule || isDrawByThreefoldRepetition) {
      return GameResult.empate;
    }
    final outcome = position.outcome;
    if (outcome == null || outcome.winner == null) return GameResult.empate;
    return outcome.winner == Side.white
        ? GameResult.vitoriaBrancas
        : GameResult.vitoriaPretas;
  }

  /// Termination reason, or null while ongoing. Checkmate takes precedence
  /// over draw counters; repetition and the fifty-move rule are handled here.
  GameTermination? get termination {
    if (!isGameOver) return null;
    if (position.isCheckmate) return GameTermination.checkmate;
    if (isDrawByThreefoldRepetition) {
      return GameTermination.threefoldRepetition;
    }
    if (isDrawByFiftyMoveRule) return GameTermination.fiftyMoveRule;
    if (position.isStalemate) return GameTermination.stalemate;
    if (position.isInsufficientMaterial) {
      return GameTermination.insufficientMaterial;
    }
    return GameTermination.unknown;
  }

  /// Legal destinations from [square], or none if it has no piece for the
  /// side to move.
  Iterable<Square> legalDestinationsFrom(Square square) {
    final destinations =
        position.legalMoves[square]?.squares.toSet() ?? <Square>{};

    // dartchess represents castling as king-to-rook for Chess960
    // compatibility. This app uses standard chess destinations g/c, with
    // final validation through `makeSan`.
    final piece = position.board.pieceAt(square);
    if (piece?.role == Role.king) {
      final rank = piece!.color == Side.white ? Rank.first : Rank.eighth;
      final kingSideRook = Square.fromCoords(File.h, rank);
      final queenSideRook = Square.fromCoords(File.a, rank);
      // A corner can also be a normal king move, check escape, or capture.
      // Convert king-to-rook only if the square actually holds a friendly
      // rook.
      final ownRook = Piece(color: piece.color, role: Role.rook);
      if (position.board.pieceAt(kingSideRook) == ownRook &&
          destinations.remove(kingSideRook)) {
        destinations.add(Square.fromCoords(File.g, rank));
      }
      if (position.board.pieceAt(queenSideRook) == ownRook &&
          destinations.remove(queenSideRook)) {
        destinations.add(Square.fromCoords(File.c, rank));
      }
    }
    return destinations;
  }

  /// Whether a pawn move from [from] to [to] reaches a promotion rank.
  bool isPromotion(Square from, Square to) {
    final piece = position.board.pieceAt(from);
    if (piece == null || piece.role != Role.pawn) return false;
    final destRank = to.rank;
    return destRank == Rank.first || destRank == Rank.eighth;
  }

  GameState copyWith({
    Chess? position,
    List<Chess>? positionHistory,
    List<String>? sanHistory,
    List<String>? uciHistory,
    List<GameMoveActor>? moveActorHistory,
    List<DateTime>? moveTimeHistoryUtc,
    Square? selectedSquare,
    bool clearSelection = false,
    bool? evaluated,
    Side? aiSide,
    bool clearAiSide = false,
    int? levelRating,
    bool? aiThinking,
    bool? hintThinking,
    String? engineError,
    bool clearEngineError = false,
    String? persistenceError,
    bool clearPersistenceError = false,
    String? gameId,
    bool clearGameId = false,
    DateTime? startedAtUtc,
    bool? campaignMode,
    bool? clockEnabled,
    int? initialTimeMs,
    int? whiteTimeMs,
    int? blackTimeMs,
  }) {
    final next = GameState._(
      position: position ?? this.position,
      positionHistory: positionHistory == null
          ? this.positionHistory
          : List.unmodifiable(positionHistory),
      sanHistory: sanHistory == null
          ? this.sanHistory
          : List.unmodifiable(sanHistory),
      uciHistory: uciHistory == null
          ? this.uciHistory
          : List.unmodifiable(uciHistory),
      moveActorHistory: moveActorHistory == null
          ? this.moveActorHistory
          : List.unmodifiable(moveActorHistory),
      moveTimeHistoryUtc: moveTimeHistoryUtc == null
          ? this.moveTimeHistoryUtc
          : List.unmodifiable(moveTimeHistoryUtc),
      selectedSquare: clearSelection
          ? null
          : (selectedSquare ?? this.selectedSquare),
      evaluated: evaluated ?? this.evaluated,
      aiSide: clearAiSide ? null : (aiSide ?? this.aiSide),
      levelRating: levelRating ?? this.levelRating,
      aiThinking: aiThinking ?? this.aiThinking,
      hintThinking: hintThinking ?? this.hintThinking,
      engineError: clearEngineError ? null : (engineError ?? this.engineError),
      persistenceError: clearPersistenceError
          ? null
          : (persistenceError ?? this.persistenceError),
      gameId: clearGameId ? null : (gameId ?? this.gameId),
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      campaignMode: campaignMode ?? this.campaignMode,
      clockEnabled: clockEnabled ?? this.clockEnabled,
      initialTimeMs: initialTimeMs ?? this.initialTimeMs,
      whiteTimeMs: whiteTimeMs ?? this.whiteTimeMs,
      blackTimeMs: blackTimeMs ?? this.blackTimeMs,
    );
    if (identical(next.position, this.position) &&
        identical(next.positionHistory, this.positionHistory)) {
      next._threefoldRepetition = _threefoldRepetition;
      next._gameOver = _gameOver;
    }
    return next;
  }

  /// Repetition identity: piece placement, side to move, castling rights, and
  /// legal en passant. Halfmove and fullmove counters are excluded.
  static String _repetitionKey(Chess position) =>
      position.fen.split(' ').take(4).join(' ');
}
