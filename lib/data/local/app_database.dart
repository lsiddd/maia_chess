import 'dart:io';

import 'package:dartchess/dartchess.dart' show Side;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/difficulty_levels.dart';
import '../../features/difficulty/domain/campaign_wins.dart';
import '../../features/stats/domain/player_stats.dart';
import '../repositories/game_repository.dart';

part 'app_database.g.dart';

@DataClassName('GameRow')
@TableIndex(
  name: 'games_status_modified',
  columns: {#status, #lastModifiedAtUtc},
)
class Games extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAtUtc => dateTime()();
  DateTimeColumn get endedAtUtc => dateTime().nullable()();
  DateTimeColumn get lastModifiedAtUtc => dateTime()();
  TextColumn get status => text().withDefault(const Constant('ongoing'))();
  IntColumn get levelRating => integer().nullable()();
  TextColumn get playerSide => text().nullable()();
  TextColumn get result => text().withDefault(const Constant('ongoing'))();
  TextColumn get termination => text().nullable()();
  BoolColumn get evaluated => boolean().withDefault(const Constant(true))();
  BoolColumn get campaignMode => boolean().withDefault(const Constant(false))();
  TextColumn get initialFen => text()();
  TextColumn get currentFen => text()();
  TextColumn get pgn => text().nullable()();
  BoolColumn get clockEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get incrementMs => integer().withDefault(const Constant(0))();
  IntColumn get initialTimeMs => integer().nullable()();
  IntColumn get whiteTimeMs => integer().nullable()();
  IntColumn get blackTimeMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GameMoveRow')
@TableIndex(name: 'game_moves_game', columns: {#gameId, #ply})
class GameMoves extends Table {
  TextColumn get gameId =>
      text().references(Games, #id, onDelete: KeyAction.cascade)();
  IntColumn get ply => integer()();
  TextColumn get uci => text()();
  TextColumn get san => text()();
  TextColumn get fenAfter => text()();
  TextColumn get actor => text()();
  DateTimeColumn get playedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {gameId, ply};
}

@DataClassName('DifficultyProgressRow')
class DifficultyProgress extends Table {
  IntColumn get rating => integer()();
  IntColumn get whiteWins => integer().withDefault(const Constant(0))();
  IntColumn get blackWins => integer().withDefault(const Constant(0))();
  BoolColumn get unlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {rating};
}

@DataClassName('RatingHistoryRow')
@TableIndex(name: 'rating_history_recorded', columns: {#recordedAtUtc})
class RatingHistory extends Table {
  TextColumn get id => text()();
  TextColumn get gameId =>
      text().unique().references(Games, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get recordedAtUtc => dateTime()();
  RealColumn get rating => real()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get showAttackedPieces =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get ownAttackedPiecesOnly =>
      boolean().withDefault(const Constant(false))();
  TextColumn get pieceSet => text().withDefault(const Constant('cburnett'))();
  TextColumn get boardTheme => text().withDefault(const Constant('brown'))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get defaultClockEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get defaultTimeMinutes =>
      integer().withDefault(const Constant(10))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Games, GameMoves, DifficultyProgress, RatingHistory, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  /// Shares the existing executor and stream notifications with a worker.
  AppDatabase.connect(DatabaseConnection super.connection);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedDefaults();
    },
    onUpgrade: (migrator, from, to) => transaction(() async {
      if (from < 1) {
        await migrator.createAll();
        await _seedDefaults();
        return;
      }
      if (from < 6) {
        await migrator.addColumn(games, games.incrementMs);
      }
      if (from < 4) {
        await migrator.addColumn(appSettings, appSettings.showAttackedPieces);
        await migrator.addColumn(
          appSettings,
          appSettings.ownAttackedPiecesOnly,
        );
      }
      if (from < 3) {
        await migrator.addColumn(appSettings, appSettings.boardTheme);
        await customStatement(
          "UPDATE app_settings SET piece_set = 'cburnett' WHERE piece_set = 'classic'",
        );
      }
      // The old rolling totals cannot identify the side of a win.
      await migrator.drop(difficultyProgress);
      await migrator.createTable(difficultyProgress);
      if (from < 5) {
        await _seedDefaults();
        await _rebuildDerivedState();
      } else {
        await _rebuildCampaignProgress();
      }
    }),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS games_library_modified_id '
        'ON games (last_modified_at_utc DESC, id DESC)',
      );
    },
  );

  Future<void> _seedDefaults() async {
    final now = DateTime.now().toUtc();
    for (final level in DifficultyLevel.all) {
      await into(difficultyProgress).insert(
        DifficultyProgressCompanion.insert(
          rating: Value(level.rating),
          unlocked: Value(level == DifficultyLevel.all.first),
          updatedAtUtc: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    await into(appSettings).insert(
      AppSettingsCompanion.insert(updatedAtUtc: now),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Append normal chronological completions without rewriting earlier ratings.
  /// Retroactive changes use the full repair projection instead.
  Future<void> recordCompletion(StoredGame game) async {
    if (!game.evaluated ||
        game.playerSide == null ||
        game.levelRating == null ||
        !{
          StoredGameResult.whiteWin,
          StoredGameResult.blackWin,
          StoredGameResult.draw,
        }.contains(game.result)) {
      return;
    }
    // Compare persisted precision, exactly as the full rebuild does. Two
    // distinct Dart timestamps can become the same SQLite timestamp.
    final storedTime =
        await (selectOnly(games)
              ..addColumns([games.endedAtUtc, games.lastModifiedAtUtc])
              ..where(games.id.equals(game.id)))
            .getSingle();
    final ended =
        (storedTime.read(games.endedAtUtc) ??
                storedTime.read(games.lastModifiedAtUtc)!)
            .toUtc();
    final last =
        await (select(ratingHistory)
              ..orderBy([
                (row) => OrderingTerm.desc(row.recordedAtUtc),
                (row) => OrderingTerm.desc(row.gameId),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (last != null &&
        (ended.isBefore(last.recordedAtUtc) ||
            (ended.isAtSameMomentAs(last.recordedAtUtc) &&
                game.id.compareTo(last.gameId) <= 0))) {
      await rebuildDerivedState();
      return;
    }
    final outcome = playerOutcome(game.result, game.playerSide!);
    final value = PlayerStatsCalculator.nextRating(
      last?.rating ?? PlayerStatsCalculator.initialRating,
      game.levelRating!,
      outcome,
    );
    await into(ratingHistory).insert(
      RatingHistoryCompanion.insert(
        id: 'rating:${game.id}',
        gameId: game.id,
        recordedAtUtc: ended,
        rating: value,
      ),
    );
    if (!game.campaignMode || outcome != PlayerGameOutcome.win) return;
    final levels = await (select(
      difficultyProgress,
    )..orderBy([(row) => OrderingTerm.asc(row.rating)])).get();
    var unlocked = true;
    for (final level in levels) {
      var wins = CampaignWins(white: level.whiteWins, black: level.blackWins);
      if (level.rating == game.levelRating) wins = wins.add(game.playerSide!);
      if (wins.white != level.whiteWins ||
          wins.black != level.blackWins ||
          unlocked != level.unlocked) {
        await (update(
          difficultyProgress,
        )..where((row) => row.rating.equals(level.rating))).write(
          DifficultyProgressCompanion(
            whiteWins: Value(wins.white),
            blackWins: Value(wins.black),
            unlocked: Value(unlocked),
            updatedAtUtc: Value(DateTime.now().toUtc()),
          ),
        );
      }
      unlocked = unlocked && wins.completed;
    }
  }

  /// Rebuild rating history and campaign progress from `games`, the source of
  /// truth. Completion and deletion callers must use the same transaction so
  /// game data and derived state commit or roll back together.
  Future<void> rebuildDerivedState() => computeWithDatabase(
    connect: AppDatabase.connect,
    computation: _rebuildOnWorker,
  );

  static Future<void> _rebuildOnWorker(AppDatabase database) =>
      database._rebuildDerivedState();

  Future<void> _rebuildDerivedState() async {
    final rows =
        await (select(games)..where(
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
            ))
            .get();
    final summaries = rows.map(_evaluatedSummary).toList(growable: false)
      ..sort((a, b) {
        final byDate = a.completedAtUtc.compareTo(b.completedAtUtc);
        return byDate != 0 ? byDate : a.gameId.compareTo(b.gameId);
      });

    final stats = const PlayerStatsCalculator().calculate(summaries);
    await delete(ratingHistory).go();
    if (stats.ratingHistory.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(
          ratingHistory,
          stats.ratingHistory
              .map(
                (point) => RatingHistoryCompanion.insert(
                  id: 'rating:${point.gameId}',
                  gameId: point.gameId,
                  recordedAtUtc: point.recordedAtUtc,
                  rating: point.value,
                ),
              )
              .toList(growable: false),
        );
      });
    }

    await _rebuildCampaignProgress();
  }

  Future<void> _rebuildCampaignProgress() async {
    final count = games.id.count();
    final totals =
        await (selectOnly(games)
              ..addColumns([games.levelRating, games.playerSide, count])
              ..where(
                games.status.equals(StoredGameStatus.completed.name) &
                    games.evaluated.equals(true) &
                    games.campaignMode.equals(true) &
                    games.levelRating.isNotNull() &
                    ((games.playerSide.equals(Side.white.name) &
                            games.result.equals(
                              StoredGameResult.whiteWin.name,
                            )) |
                        (games.playerSide.equals(Side.black.name) &
                            games.result.equals(
                              StoredGameResult.blackWin.name,
                            ))),
              )
              ..groupBy([games.levelRating, games.playerSide]))
            .get();
    final byLevel = <int, CampaignWins>{};
    for (final row in totals) {
      final rating = row.read(games.levelRating)!;
      final side = Side.values.byName(row.read(games.playerSide)!);
      byLevel[rating] = (byLevel[rating] ?? const CampaignWins()).add(
        side,
        row.read(count)!,
      );
    }

    var levelUnlocked = true;
    final now = DateTime.now().toUtc();
    for (final level in DifficultyLevel.all) {
      final wins = byLevel[level.rating] ?? const CampaignWins();
      await into(difficultyProgress).insertOnConflictUpdate(
        DifficultyProgressCompanion.insert(
          rating: Value(level.rating),
          whiteWins: Value(wins.white),
          blackWins: Value(wins.black),
          unlocked: Value(levelUnlocked),
          updatedAtUtc: now,
        ),
      );
      levelUnlocked = levelUnlocked && wins.completed;
    }
  }

  EvaluatedGameSummary _evaluatedSummary(GameRow row) {
    final side = Side.values.byName(row.playerSide!);
    final result = StoredGameResult.values.byName(row.result);
    return EvaluatedGameSummary(
      gameId: row.id,
      completedAtUtc: (row.endedAtUtc ?? row.lastModifiedAtUtc).toUtc(),
      levelRating: row.levelRating!,
      outcome: playerOutcome(result, side),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documents = await getApplicationDocumentsDirectory();
    final file = File(p.join(documents.path, 'maia_chess.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
