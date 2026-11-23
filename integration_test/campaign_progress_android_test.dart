import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/stats/presentation/stats_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native Android: persist, unlock, render, and rebuild statistics',
    (tester) async {
      final temporaryDirectory = await getTemporaryDirectory();
      final databaseFile = io.File(
        '${temporaryDirectory.path}/campaign_progress_android_test.sqlite',
      );
      if (await databaseFile.exists()) await databaseFile.delete();

      final database = AppDatabase.forTesting(
        NativeDatabase.createInBackground(databaseFile),
      );
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      final games = container.read(gameRepositoryProvider);
      final stats = container.read(statsRepositoryProvider);
      final progress = container.read(progressRepositoryProvider);

      try {
        final first = _campaignGame(
          id: 'campaign-device-win-1',
          hour: 12,
          result: StoredGameResult.whiteWin,
        );
        await games.beginGame(first.ongoing);
        expect(await games.completeGame(first.completed), isTrue);
        expect(
          await games.completeGame(first.completed),
          isFalse,
          reason: 'Completing a game again must not duplicate derived state.',
        );

        var snapshot = await stats.get();
        var levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 1);
        expect(snapshot.ratingHistory, hasLength(1));
        expect(levels.first.wins.white, 1);
        expect(levels.first.wins.black, 0);
        expect(levels[1].unlocked, isFalse);

        final second = _campaignGame(
          id: 'campaign-device-loss',
          hour: 13,
          result: StoredGameResult.blackWin,
        );
        final third = _campaignGame(
          id: 'campaign-device-win-2',
          hour: 14,
          result: StoredGameResult.whiteWin,
        );
        await games.beginGame(second.ongoing);
        expect(await games.completeGame(second.completed), isTrue);
        await games.beginGame(third.ongoing);
        expect(await games.completeGame(third.completed), isTrue);

        levels = await progress.getAll();
        expect(levels.first.wins.white, 2);
        expect(levels[1].unlocked, isFalse);
        final blackWins = [
          for (final hour in [15, 16])
            _campaignGame(
              id: 'black-$hour',
              hour: hour,
              playerSide: Side.black,
              result: StoredGameResult.blackWin,
            ),
        ];
        for (final win in blackWins) {
          await games.beginGame(win.ongoing);
          expect(await games.completeGame(win.completed), isTrue);
        }
        snapshot = await stats.get();
        levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 5);
        expect(snapshot.ratingHistory, hasLength(5));
        expect(snapshot.resultsByLevel[600]?.wins, 4);
        expect(snapshot.resultsByLevel[600]?.losses, 1);
        expect(levels.first.levelCompleted, isTrue);
        expect(levels.first.wins.black, 2);
        expect(levels[1].unlocked, isTrue);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CampaignScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Climb through all 16 Maia-3 levels'), findsOneWidget);
        final level800 = find.text('Maia-3 800');
        await tester.scrollUntilVisible(level800, 150);
        expect(level800, findsOneWidget);
        await tester.scrollUntilVisible(find.text('Maia-3 600'), 150);
        expect(find.text('Level completed'), findsOneWidget);
        expect(find.text('Play again'), findsOneWidget);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StatsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('5 rated games'), findsOneWidget);
        expect(find.text('Current streak'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(r'Rating chart with 5 points; current rating'),
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('4W  0D  1L'),
          250,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('4W  0D  1L'), findsOneWidget);

        await games.deleteGame(third.ongoing.id);
        snapshot = await stats.get();
        levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 4);
        expect(snapshot.ratingHistory, hasLength(4));
        expect(snapshot.resultsByLevel[600]?.wins, 3);
        expect(snapshot.resultsByLevel[600]?.losses, 1);
        expect(levels.first.wins.white, 1);
        expect(levels.first.wins.black, 2);
        expect(levels[1].unlocked, isFalse);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CampaignScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('White 1/2 • Black 2/2'), findsOneWidget);
        await tester.scrollUntilVisible(level800, 150);
        final level800Card = find.ancestor(
          of: level800,
          matching: find.byType(Card),
        );
        expect(
          find.descendant(of: level800Card, matching: find.text('Locked')),
          findsOneWidget,
        );

        for (final win in blackWins) {
          await games.deleteGame(win.ongoing.id);
        }
        await games.deleteGame(first.ongoing.id);
        await games.deleteGame(second.ongoing.id);
        snapshot = await stats.get();
        levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 0);
        expect(snapshot.ratingHistory, isEmpty);
        expect(levels.first.wins.white, 0);
        expect(levels.first.wins.black, 0);
        expect(levels.first.unlocked, isTrue);
        expect(levels.skip(1).every((level) => !level.unlocked), isTrue);
        expect(await database.select(database.ratingHistory).get(), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await database.close();
        if (await databaseFile.exists()) await databaseFile.delete();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

({StoredGame ongoing, StoredGame completed}) _campaignGame({
  required String id,
  required int hour,
  Side playerSide = Side.white,
  required StoredGameResult result,
}) {
  final startedAt = DateTime.utc(2026, 8, 6, hour);
  final ongoing = StoredGame(
    id: id,
    startedAtUtc: startedAt,
    lastModifiedAtUtc: startedAt,
    status: StoredGameStatus.ongoing,
    levelRating: 600,
    playerSide: playerSide,
    result: StoredGameResult.ongoing,
    evaluated: true,
    campaignMode: true,
    initialFen: Chess.initial.fen,
    currentFen: Chess.initial.fen,
    moves: const [],
  );
  return (
    ongoing: ongoing,
    completed: ongoing.copyWith(
      endedAtUtc: startedAt.add(const Duration(minutes: 20)),
      lastModifiedAtUtc: startedAt.add(const Duration(minutes: 20)),
      status: StoredGameStatus.completed,
      result: result,
      termination: GameTermination.checkmate,
    ),
  );
}
