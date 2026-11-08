import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/progress_repository.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/stats/domain/player_stats.dart';

void main() {
  group('evaluateCampaignWindow', () {
    test('qualifies with two wins in three games', () {
      final result = evaluateCampaignWindow(
        const [
          PlayerGameOutcome.win,
          PlayerGameOutcome.loss,
          PlayerGameOutcome.win,
        ],
        winsRequired: 2,
        windowSize: 3,
      );

      expect(result.qualified, isTrue);
      expect(result.wins, 2);
      expect(result.games, 3);
    });

    test('qualification persists after later losses', () {
      final result = evaluateCampaignWindow(
        const [
          PlayerGameOutcome.win,
          PlayerGameOutcome.win,
          PlayerGameOutcome.loss,
          PlayerGameOutcome.loss,
          PlayerGameOutcome.loss,
        ],
        winsRequired: 2,
        windowSize: 3,
      );

      expect(result.qualified, isTrue);
      expect(result.wins, 2);
      expect(result.games, 2);
    });
  });

  testWidgets('campaign shows progress and locked levels', (tester) async {
    final now = DateTime.utc(2026, 8, 5);
    final levels = [
      DifficultyProgressModel(
        rating: 1100,
        validWins: 1,
        gamesInWindow: 2,
        unlocked: true,
        winsRequired: 2,
        windowSize: 3,
        updatedAtUtc: now,
      ),
      DifficultyProgressModel(
        rating: 1200,
        validWins: 0,
        gamesInWindow: 0,
        unlocked: false,
        winsRequired: 2,
        windowSize: 3,
        updatedAtUtc: now,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          difficultyProgressProvider.overrideWith(
            (ref) => Stream.value(levels),
          ),
        ],
        child: const MaterialApp(home: CampaignScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Climb through all 16 Maia-3 levels'), findsOneWidget);
    expect(find.text('1/2 wins • 2/3 games'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Play level'), 200);
    expect(find.text('Play level'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Locked'), 200);
    expect(find.text('Locked'), findsOneWidget);
  });
}
