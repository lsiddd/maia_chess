import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/core/theming/app_page_route.dart';
import 'package:maia_chess/core/theming/app_theme.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/difficulty/presentation/new_game_vs_ai_screen.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/history/presentation/history_screen.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';
import 'package:maia_chess/features/review/presentation/game_review_screen.dart';
import 'package:maia_chess/features/review/presentation/review_chart.dart';
import 'package:maia_chess/features/settings/presentation/appearance_screen.dart';
import 'package:maia_chess/features/stats/presentation/stats_screen.dart';
import 'package:maia_chess/main.dart';

/// Repeatable screenshots use a separate in-memory database, never player data.
/// Run with test_driver/ui_audit.dart to save the rendered Android frames.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android UI audit: light, dark, game and navigation', (
    tester,
  ) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );

    Future<void> capture(
      String name,
      Widget screen, {
      required bool dark,
    }) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            key: UniqueKey(),
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (screen is! HomeScreen) {
        unawaited(
          navigator.currentState!.push(
            AppPageRoute<void>(builder: (_) => screen),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(BackButton),
          findsOneWidget,
          reason: '$name needs a visible way back',
        );
      }
      if (screen is GameReviewScreen) {
        // The native engine completes asynchronously; a settled frame alone
        // does not establish that the completed review is on screen.
        final chart = find.byType(ReviewChart);
        for (
          var attempt = 0;
          attempt < 300 && chart.evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          chart,
          findsOneWidget,
          reason: 'Capture the completed native Stockfish review',
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: '$name, dark=$dark');
      await binding.takeScreenshot('$name-${dark ? 'dark' : 'light'}');
    }

    try {
      await binding.convertFlutterSurfaceToImage();
      for (final dark in [false, true]) {
        final screens = <String, Widget>{
          'home': const HomeScreen(),
          'free-play': const NewGameVsAiScreen(),
          'campaign': const CampaignScreen(),
          'appearance': const AppearanceScreen(),
          'library-empty': const HistoryScreen(),
          'stats-empty': const StatsScreen(),
          'game': const GameScreen(),
        };
        for (final entry in screens.entries) {
          await capture(entry.key, entry.value, dark: dark);
        }
      }

      final reviewGame = await _seedRatedGames(container);
      final replayed = const GameReplayer().replay(reviewGame);
      for (final dark in [false, true]) {
        final populated = <String, Widget>{
          'library-populated': const HistoryScreen(),
          'stats-populated': const StatsScreen(),
          'replay': ReplayScreen(gameId: reviewGame.id),
          'review': GameReviewScreen(
            game: reviewGame,
            replayed: replayed,
            initialPly: 3,
          ),
        };
        for (final entry in populated.entries) {
          await capture(entry.key, entry.value, dark: dark);
        }
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaiaChessApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Your next move.'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(gameControllerProvider.notifier).shutdownEngines();
      container.dispose();
      await database.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

/// Legal, reproducible games go through the same completion transaction as play,
/// including derived ratings. PGN parsing supplies canonical SAN/FEN fixtures.
Future<StoredGame> _seedRatedGames(ProviderContainer container) async {
  final games = container.read(gameRepositoryProvider);
  const fixtures = [
    (
      id: 'ui-win',
      rating: 1100,
      pgn: '[Result "1-0"]\n\n1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0',
    ),
    (
      id: 'ui-loss',
      rating: 1200,
      pgn: '[Result "0-1"]\n\n1. f3 e5 2. g4 Qh4# 0-1',
    ),
    (
      id: 'ui-draw',
      rating: 1100,
      pgn:
          '[Result "1/2-1/2"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 1/2-1/2',
    ),
  ];
  for (final (index, fixture) in fixtures.indexed) {
    final date = DateTime.utc(2026, 11, 1 + index, 18);
    final parsed = const PgnService().parseImport(
      pgn: fixture.pgn,
      id: fixture.id,
      importedAtUtc: date,
    );
    final ongoing = StoredGame(
      id: fixture.id,
      startedAtUtc: date,
      lastModifiedAtUtc: date,
      status: StoredGameStatus.ongoing,
      result: StoredGameResult.ongoing,
      evaluated: true,
      campaignMode: false,
      levelRating: fixture.rating,
      playerSide: Side.white,
      initialFen: parsed.initialFen,
      currentFen: parsed.initialFen,
      moves: const [],
    );
    await games.beginGame(ongoing);
    expect(
      await games.completeGame(
        ongoing.copyWith(
          endedAtUtc: date.add(const Duration(minutes: 10)),
          lastModifiedAtUtc: date.add(const Duration(minutes: 10)),
          status: StoredGameStatus.completed,
          result: parsed.result,
          termination: parsed.result == StoredGameResult.draw
              ? GameTermination.unknown
              : GameTermination.checkmate,
          currentFen: parsed.currentFen,
          pgn: fixture.pgn,
          moves: [
            for (final move in parsed.moves)
              StoredGameMove(
                ply: move.ply,
                uci: move.uci,
                san: move.san,
                fenAfter: move.fenAfter,
                actor: move.ply.isOdd
                    ? GameMoveActor.player
                    : GameMoveActor.maia,
                playedAtUtc: date.add(Duration(seconds: move.ply * 30)),
              ),
          ],
        ),
      ),
      isTrue,
    );
  }
  final stats = await container.read(statsRepositoryProvider).get();
  expect(stats.evaluatedGames, 3);
  expect(stats.ratingHistory, hasLength(3));
  expect(await games.watchLibrary().first, hasLength(3));
  return (await games.getGame('ui-loss'))!;
}
