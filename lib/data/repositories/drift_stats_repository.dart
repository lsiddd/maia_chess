import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart';

import '../../features/stats/domain/player_stats.dart';
import '../local/app_database.dart';
import 'game_repository.dart';
import 'stats_repository.dart';

class DriftStatsRepository implements StatsRepository {
  DriftStatsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<PlayerStatsSnapshot> watch() {
    // Keep the initial/update signal tiny. Row mapping, sorting and rating
    // projection happen in the worker through the shared connection.
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.games, _db.ratingHistory})
        .watch()
        .asyncMap((_) => get());
  }

  @override
  Future<PlayerStatsSnapshot> get() => _db.computeWithDatabase(
    connect: AppDatabase.connect,
    computation: _readOnWorker,
  );

  static Future<PlayerStatsSnapshot> _readOnWorker(AppDatabase database) =>
      DriftStatsRepository(database)._readSnapshot();

  Future<PlayerStatsSnapshot> _readSnapshot() async {
    return _snapshot(await _eligibleGamesQuery().get());
  }

  SimpleSelectStatement<$GamesTable, GameRow> _eligibleGamesQuery() {
    return _db.select(_db.games)
      ..where(
        (row) =>
            row.status.equals(StoredGameStatus.completed.name) &
            row.evaluated.equals(true) &
            row.levelRating.isNotNull() &
            row.playerSide.isNotNull() &
            row.result.isIn([
              StoredGameResult.whiteWin.name,
              StoredGameResult.blackWin.name,
              StoredGameResult.draw.name,
            ]),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.endedAtUtc),
        (row) => OrderingTerm.asc(row.id),
      ]);
  }

  Future<PlayerStatsSnapshot> _snapshot(List<GameRow> rows) async {
    final calculated = const PlayerStatsCalculator().calculate(
      rows.map(_summary),
    );
    final historyRows =
        await (_db.select(_db.ratingHistory)..orderBy([
              (row) => OrderingTerm.asc(row.recordedAtUtc),
              (row) => OrderingTerm.asc(row.gameId),
            ]))
            .get();
    final history = historyRows
        .map(
          (row) => RatingPoint(
            gameId: row.gameId,
            recordedAtUtc: row.recordedAtUtc.toUtc(),
            value: row.rating,
          ),
        )
        .toList(growable: false);
    return calculated.copyWith(
      estimatedRating: history.isEmpty
          ? PlayerStatsCalculator.initialRating
          : history.last.value,
      ratingHistory: List.unmodifiable(history),
    );
  }

  EvaluatedGameSummary _summary(GameRow row) {
    final side = Side.values.byName(row.playerSide!);
    final result = StoredGameResult.values.byName(row.result);
    return EvaluatedGameSummary(
      gameId: row.id,
      completedAtUtc: (row.endedAtUtc ?? row.lastModifiedAtUtc).toUtc(),
      levelRating: row.levelRating!,
      outcome: playerOutcome(result, side),
      campaignMode: row.campaignMode,
    );
  }
}
