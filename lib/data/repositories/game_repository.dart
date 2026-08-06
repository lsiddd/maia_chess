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
  Stream<List<StoredGame>> watchLibrary();

  Stream<StoredGame?> watchActiveGame();

  Future<StoredGame?> getActiveGame();

  Future<StoredGame?> getGame(String id);

  /// Cria o único autosave ativo. Qualquer partida ainda em andamento é
  /// removida na mesma transação antes da inserção.
  Future<void> beginGame(StoredGame game);

  /// Substitui o snapshot completo e seus lances, permitindo que undo seja
  /// persistido sem deixar lances órfãos.
  Future<void> saveOngoing(StoredGame game);

  /// Persiste snapshot, PGN, resultado e eventual vitória de campanha em
  /// uma transação. Retorna `false` se a partida já havia sido finalizada.
  Future<bool> completeGame(StoredGame game);

  /// Importa somente depois que todo o PGN tiver sido validado em memória.
  Future<void> importGame(StoredGame game);

  Future<void> deleteGame(String id);
}

/// Resultado de uma partida do ponto de vista de [playerSide], único lugar
/// onde essa regra é calculada (antes duplicada entre `AppDatabase` e
/// `DriftStatsRepository`, ver AUDITORIA_TECNICA.md, AUD-009).
PlayerGameOutcome playerOutcome(StoredGameResult result, Side playerSide) {
  if (result == StoredGameResult.draw) return PlayerGameOutcome.draw;
  final playerWon =
      (playerSide == Side.white && result == StoredGameResult.whiteWin) ||
      (playerSide == Side.black && result == StoredGameResult.blackWin);
  return playerWon ? PlayerGameOutcome.win : PlayerGameOutcome.loss;
}
