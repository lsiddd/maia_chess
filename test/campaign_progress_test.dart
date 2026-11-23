import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/progress_repository.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/difficulty/domain/campaign_wins.dart';

void main() {
  for (final firstSide in Side.values) {
    test(
      'requires two wins per side even after extra wins as ${firstSide.name}',
      () {
        var wins = const CampaignWins().add(firstSide, 4);
        expect(wins.fraction, 0.5);
        expect(wins.completed, isFalse);
        wins = wins.add(firstSide.opposite);
        expect(wins.completed, isFalse);
        wins = wins.add(firstSide.opposite);
        expect(wins.completed, isTrue);
        expect(wins.fraction, 1);
      },
    );
  }

  testWidgets('campaign shows progress and locked levels', (tester) async {
    final now = DateTime.utc(2026, 8, 5);
    final levels = [
      DifficultyProgressModel(
        rating: 1100,
        wins: const CampaignWins(white: 1),
        unlocked: true,
        updatedAtUtc: now,
      ),
      DifficultyProgressModel(
        rating: 1200,
        wins: const CampaignWins(),
        unlocked: false,
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
    expect(find.text('White 1/2 • Black 0/2'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Play level'), 200);
    expect(find.text('Play level'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Locked'), 200);
    expect(find.text('Locked'), findsOneWidget);
  });
}
