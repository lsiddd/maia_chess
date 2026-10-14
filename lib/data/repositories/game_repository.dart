import 'package:dartchess/dartchess.dart';

import '../../features/stats/domain/player_stats.dart';

enum StoredGameStatus { ongoing, completed }

enum StoredGameResult { ongoing, whiteWin, blackWin, draw, unknown }

enum GameTermination {
  checkmate,
  stalemate,
  insufficientMaterial,
  threefoldRepetition,
  fiftyMoveRule,
  imported,
  unknown,
}

enum GameMoveActor { player, maia, imported }

class StoredGameMove {
  const StoredGameMove({
    required this.ply,
    required this.uci,
    required this.san,
    required this.fenAfter,
    required this.actor,
    required this.playedAtUtc,
  });

  final int ply;
  final String uci;
  final String san;
  final String fenAfter;
  final GameMoveActor actor;
  final DateTime playedAtUtc;
}

class StoredGame {
  const StoredGame({
    required this.id,
    required this.startedAtUtc,
    required this.lastModifiedAtUtc,
    required this.status,
    required this.result,
    required this.evaluated,
    required this.campaignMode,
    required this.initialFen,
    required this.currentFen,
    required this.moves,
    this.endedAtUtc,
    this.levelRating,
    this.playerSide,
    this.termination,
    this.pgn,
    this.clockEnabled = false,
    this.initialTimeMs,
    this.whiteTimeMs,
    this.blackTimeMs,
  });

  final String id;
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final DateTime lastModifiedAtUtc;
  final StoredGameStatus status;
  final int? levelRating;
  final Side? playerSide;
  final StoredGameResult result;
  final GameTermination? termination;
  final bool evaluated;
  final bool campaignMode;
  final String initialFen;
  final String currentFen;
  final String? pgn;
  final bool clockEnabled;
  final int? initialTimeMs;
  final int? whiteTimeMs;
  final int? blackTimeMs;
  final List<StoredGameMove> moves;

  StoredGame copyWith({
    DateTime? endedAtUtc,
    DateTime? lastModifiedAtUtc,
    StoredGameStatus? status,
    StoredGameResult? result,
    GameTermination? termination,
    bool? evaluated,
    String? currentFen,
    String? pgn,
    List<StoredGameMove>? moves,
  }) {
    return StoredGame(
      id: id,
      startedAtUtc: startedAtUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
      lastModifiedAtUtc: lastModifiedAtUtc ?? this.lastModifiedAtUtc,
      status: status ?? this.status,
      levelRating: levelRating,
      playerSide: playerSide,
      result: result ?? this.result,
      termination: termination ?? this.termination,
      evaluated: evaluated ?? this.evaluated,
      campaignMode: campaignMode,
      initialFen: initialFen,
      currentFen: currentFen ?? this.currentFen,
      pgn: pgn ?? this.pgn,
      clockEnabled: clockEnabled,
      initialTimeMs: initialTimeMs,
      whiteTimeMs: whiteTimeMs,
      blackTimeMs: blackTimeMs,
      moves: moves ?? this.moves,
    );
  }
}

abstract interface class GameRepository {
  /// Read all games by default, or a bounded page when [limit] is supplied.
  Stream<List<StoredGame>> watchLibrary({int? limit, int offset = 0});

  Stream<StoredGame?> watchActiveGame();

  Future<StoredGame?> getActiveGame();

  Future<StoredGame?> getGame(String id);

  /// Create the sole active autosave. Remove any ongoing game in the same
  /// transaction before inserting its replacement. If [canCommit] rejects
  /// after the writes, roll back the replacement.
  Future<void> beginGame(StoredGame game, {bool Function()? canCommit});

  /// Persist the snapshot and reconcile changed moves, including the suffix
  /// removed by undo.
  Future<void> saveOngoing(StoredGame game);

  /// Persist the snapshot, PGN, result, and derived rating/campaign state in
  /// one transaction. Return `false` if the game was already completed.
  Future<bool> completeGame(StoredGame game);

  /// Import only after the entire PGN has been validated in memory.
  Future<void> importGame(StoredGame game);

  Future<void> deleteGame(String id);
}

class GameStartCancelledException implements Exception {
  const GameStartCancelledException();
}

/// Map a stored result to the outcome for [playerSide]. Shared by rating and
/// campaign projections.
PlayerGameOutcome playerOutcome(StoredGameResult result, Side playerSide) {
  if (result == StoredGameResult.draw) return PlayerGameOutcome.draw;
  final playerWon =
      (playerSide == Side.white && result == StoredGameResult.whiteWin) ||
      (playerSide == Side.black && result == StoredGameResult.blackWin);
  return playerWon ? PlayerGameOutcome.win : PlayerGameOutcome.loss;
}
