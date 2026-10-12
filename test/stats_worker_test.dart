import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/data/repositories/drift_stats_repository.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';

void main() {
  late AppDatabase database;
  late DriftGameRepository games;
  late DriftStatsRepository stats;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    games = DriftGameRepository(database);
    stats = DriftStatsRepository(database);
  });
  tearDown(() => database.close());

  test(
    'worker sees the transaction and reports a changed result without a new game',
    () async {
      final game = _game('win');
      await games.beginGame(game);
      final updates = StreamIterator(stats.watch());
      addTearDown(updates.cancel);
      expect(await updates.moveNext(), isTrue);
      expect(updates.current.evaluatedGames, 0);

      final winning = updates.moveNext();
      expect(await games.completeGame(_completed(game)), isTrue);
      expect(await winning, isTrue);
      expect(updates.current.evaluatedGames, 1);
      expect(updates.current.currentStreak, 1);
      expect(updates.current.estimatedRating, greaterThan(1500));

      final losing = updates.moveNext();
      await database.transaction(() async {
        await (database.update(database.games)
              ..where((row) => row.id.equals(game.id)))
            .write(const GamesCompanion(result: Value('blackWin')));
        await database.rebuildDerivedState();
      });
      expect(await losing, isTrue);
      expect(updates.current.evaluatedGames, 1);
      expect(updates.current.currentStreak, 0);
      expect(updates.current.resultsByLevel[1100]!.losses, 1);
      expect(updates.current.estimatedRating, lessThan(1500));
    },
  );

  test(
    'worker failure rolls back completion and rating history together',
    () async {
      final previous = _game('previous');
      await games.beginGame(previous);
      await games.completeGame(_completed(previous));
      final oldStats = await stats.get();
      final next = _game('failure');
      await games.beginGame(next);
      await database.customStatement('''
CREATE TRIGGER fail_rating BEFORE INSERT ON rating_history
BEGIN SELECT RAISE(ABORT, 'forced_projection_failure'); END
''');

      await expectLater(
        games.completeGame(_completed(next)),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('forced_projection_failure'),
          ),
        ),
      );
      expect((await games.getGame(next.id))!.status, StoredGameStatus.ongoing);
      final restored = await stats.get();
      expect(restored.evaluatedGames, 1);
      expect(restored.estimatedRating, oldStats.estimatedRating);
      expect(restored.ratingHistory.single.gameId, previous.id);
    },
  );

  test('stream observes rating writes from the worker connection', () async {
    final game = _game('rating-update');
    await games.beginGame(game);
    await games.completeGame(_completed(game));
    final updates = StreamIterator(stats.watch());
    addTearDown(updates.cancel);
    expect(await updates.moveNext(), isTrue);
    final changed = updates.moveNext();
    await database.computeWithDatabase(
      connect: AppDatabase.connect,
      computation: _changeRating,
    );
    expect(await changed, isTrue);
    expect(updates.current.estimatedRating, 1700);
    expect(updates.current.evaluatedGames, 1);
  });
}

Future<void> _changeRating(AppDatabase database) async {
  await database
      .update(database.ratingHistory)
      .write(const RatingHistoryCompanion(rating: Value(1700)));
}

StoredGame _game(String id) => StoredGame(
  id: id,
  startedAtUtc: DateTime.utc(2026, 10, 11),
  lastModifiedAtUtc: DateTime.utc(2026, 10, 11),
  status: StoredGameStatus.ongoing,
  result: StoredGameResult.ongoing,
  evaluated: true,
  campaignMode: true,
  levelRating: 1100,
  playerSide: Side.white,
  initialFen: Chess.initial.fen,
  currentFen: Chess.initial.fen,
  moves: const [],
);

StoredGame _completed(StoredGame game) => game.copyWith(
  status: StoredGameStatus.completed,
  result: StoredGameResult.whiteWin,
  endedAtUtc: DateTime.utc(2026, 10, 11, 1),
  termination: GameTermination.unknown,
);
