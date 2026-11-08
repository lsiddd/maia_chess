import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/core/theming/app_theme.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/stats/domain/player_stats.dart';
import 'package:maia_chess/features/stats/presentation/stats_screen.dart';

void main() {
  testWidgets('statistics screen shows rating, streaks, and results', (
    tester,
  ) async {
    final snapshot = PlayerStatsSnapshot(
      estimatedRating: 1532.4,
      ratingHistory: [
        RatingPoint(
          gameId: 'one',
          recordedAtUtc: DateTime.utc(2026, 8, 5),
          value: 1516,
        ),
        RatingPoint(
          gameId: 'two',
          recordedAtUtc: DateTime.utc(2026, 8, 6),
          value: 1532.4,
        ),
      ],
      resultsByLevel: const {1500: LevelResults(wins: 2, losses: 1, draws: 1)},
      currentStreak: 2,
      recordStreak: 4,
      evaluatedGames: 4,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerStatsProvider.overrideWith((ref) => Stream.value(snapshot)),
        ],
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1532'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4 games'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('2W  1D  1L'), findsOneWidget);
  });

  testWidgets(
    'results show only played levels in rating order with correct plurals',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1000);
      addTearDown(tester.view.reset);
      const snapshot = PlayerStatsSnapshot(
        estimatedRating: 1500,
        ratingHistory: [],
        resultsByLevel: {
          1200: LevelResults(losses: 2),
          600: LevelResults(),
          1100: LevelResults(wins: 1),
          1300: LevelResults(),
        },
        currentStreak: 1,
        recordStreak: 2,
        evaluatedGames: 3,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerStatsProvider.overrideWith((ref) => Stream.value(snapshot)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 win'), findsOneWidget);
      expect(find.text('2 wins'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Maia 1200'), 150);
      await tester.pumpAndSettle();
      expect(find.text('Maia 600'), findsNothing);
      expect(find.text('Maia 1300'), findsNothing);
      expect(find.text('1 game'), findsOneWidget);
      expect(find.text('2 games'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Maia 1100')).dy,
        lessThan(tester.getTopLeft(find.text('Maia 1200')).dy),
      );
      expect(
        find.bySemanticsLabel('Maia 1100. 1 game: 1 win, 0 draws, 0 losses.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Maia 1200. 2 games: 0 wins, 0 draws, 2 losses.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('one rated game uses singular count', (tester) async {
    const snapshot = PlayerStatsSnapshot(
      estimatedRating: 1516,
      ratingHistory: [],
      resultsByLevel: {1100: LevelResults(wins: 1)},
      currentStreak: 1,
      recordStreak: 1,
      evaluatedGames: 1,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerStatsProvider.overrideWith((ref) => Stream.value(snapshot)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 rated game'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final populated in [false, true]) {
      testWidgets(
        'statistics fit large text: dark=$dark, populated=$populated',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 480);
          addTearDown(tester.view.reset);
          final snapshot = populated
              ? PlayerStatsSnapshot(
                  estimatedRating: 1532,
                  ratingHistory: [
                    RatingPoint(
                      gameId: 'first',
                      recordedAtUtc: DateTime.utc(2026, 1),
                      value: 1516,
                    ),
                    RatingPoint(
                      gameId: 'latest',
                      recordedAtUtc: DateTime.utc(2026, 2),
                      value: 1532,
                    ),
                  ],
                  resultsByLevel: const {
                    1500: LevelResults(wins: 2, draws: 1, losses: 1),
                  },
                  currentStreak: 2,
                  recordStreak: 2,
                  evaluatedGames: 4,
                )
              : PlayerStatsSnapshot.empty();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                playerStatsProvider.overrideWith(
                  (ref) => Stream.value(snapshot),
                ),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const StatsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (!populated) {
            expect(find.text('1500'), findsNothing);
            await tester.scrollUntilVisible(
              find.text('Your progress starts here.'),
              150,
            );
          }
          await tester.scrollUntilVisible(find.text('Results by level'), 150);
          if (populated) {
            await tester.scrollUntilVisible(find.text('Maia 1500'), 150);
            expect(
              find.bySemanticsLabel(
                'Maia 1500. 4 games: 2 wins, 1 draw, 1 loss.',
              ),
              findsOneWidget,
            );
          } else {
            await tester.scrollUntilVisible(
              find.textContaining('Your results will appear here'),
              150,
            );
            expect(
              find.textContaining('Your results will appear here'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
