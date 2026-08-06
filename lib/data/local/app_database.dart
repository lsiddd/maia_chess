import 'dart:io';

import 'package:dartchess/dartchess.dart' show Side;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/difficulty_levels.dart';
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
  IntColumn get validWins => integer().withDefault(const Constant(0))();
  IntColumn get windowGames => integer().withDefault(const Constant(0))();
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
  TextColumn get pieceSet => text().withDefault(const Constant('classic'))();
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

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedDefaults();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 1) {
        await migrator.createAll();
        await _seedDefaults();
        return;
      }
      if (from < 2) {
        await migrator.addColumn(
          difficultyProgress,
          difficultyProgress.windowGames,
        );
        await rebuildDerivedState();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaults() async {
    final now = DateTime.now().toUtc();
    for (var rating = 1100; rating <= 1900; rating += 100) {
      await into(difficultyProgress).insert(
        DifficultyProgressCompanion.insert(
          rating: Value(rating),
          unlocked: Value(rating == 1100),
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

  /// Reconstrói todas as projeções da Fase 5 a partir de `games`, a fonte de
  /// verdade. O chamador deve executar este método dentro da mesma transação
  /// da conclusão/exclusão que motivou a reconstrução.
  Future<void> rebuildDerivedState() async {
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

    var levelUnlocked = true;
    final now = DateTime.now().toUtc();
    for (final level in DifficultyLevel.all) {
      final campaignGames = summaries
          .where(
            (game) => game.campaignMode && game.levelRating == level.rating,
          )
          .map((game) => game.outcome);
      final window = evaluateCampaignWindow(
        campaignGames,
        winsRequired: level.winsRequired,
        windowSize: level.windowSize,
      );
      await into(difficultyProgress).insertOnConflictUpdate(
        DifficultyProgressCompanion.insert(
          rating: Value(level.rating),
          validWins: Value(window.wins),
          windowGames: Value(window.games),
          unlocked: Value(levelUnlocked),
          updatedAtUtc: now,
        ),
      );
      levelUnlocked = levelUnlocked && window.qualified;
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
      campaignMode: row.campaignMode,
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
