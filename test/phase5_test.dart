import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/progress_repository.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/stats/domain/player_stats.dart';
import 'package:maia_chess/features/stats/presentation/stats_screen.dart';

void main() {
  group('PlayerStatsCalculator', () {
    test('aplica Elo em ordem cronológica e calcula streak de vitórias', () {
      final stats = const PlayerStatsCalculator().calculate([
        EvaluatedGameSummary(
          gameId: 'loss',
          completedAtUtc: DateTime.utc(2026, 8, 5, 14),
          levelRating: 1500,
          outcome: PlayerGameOutcome.loss,
          campaignMode: false,
        ),
        EvaluatedGameSummary(
          gameId: 'win-1',
          completedAtUtc: DateTime.utc(2026, 8, 5, 12),
          levelRating: 1500,
          outcome: PlayerGameOutcome.win,
          campaignMode: false,
        ),
        EvaluatedGameSummary(
          gameId: 'win-2',
          completedAtUtc: DateTime.utc(2026, 8, 5, 13),
          levelRating: 1500,
          outcome: PlayerGameOutcome.win,
          campaignMode: true,
        ),
      ]);

      expect(stats.ratingHistory.map((point) => point.gameId), [
        'win-1',
        'win-2',
        'loss',
      ]);
      expect(stats.ratingHistory.first.value, 1516);
      expect(stats.currentStreak, 0);
      expect(stats.recordStreak, 2);
      expect(stats.resultsByLevel[1500]?.wins, 2);
      expect(stats.resultsByLevel[1500]?.losses, 1);
    });

    test('empate zera streak e conta meio ponto no rating', () {
      final stats = const PlayerStatsCalculator().calculate([
        EvaluatedGameSummary(
          gameId: 'win',
          completedAtUtc: DateTime.utc(2026, 8, 5, 12),
          levelRating: 1500,
          outcome: PlayerGameOutcome.win,
          campaignMode: false,
        ),
        EvaluatedGameSummary(
          gameId: 'draw',
          completedAtUtc: DateTime.utc(2026, 8, 5, 13),
          levelRating: 1500,
          outcome: PlayerGameOutcome.draw,
          campaignMode: false,
        ),
      ]);

      expect(stats.currentStreak, 0);
      expect(stats.recordStreak, 1);
      expect(stats.resultsByLevel[1500]?.draws, 1);
      expect(stats.estimatedRating, lessThan(1516));
      expect(stats.estimatedRating, greaterThan(1500));
    });
  });

  group('evaluateCampaignWindow', () {
    test('qualifica ao obter duas vitórias em três partidas', () {
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

    test(
      'conquista permanece mesmo se partidas posteriores forem derrotas',
      () {
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
      },
    );
  });

  testWidgets('tela de estatísticas mostra rating, streaks e placar', (
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
    expect(find.text('Sequência atual'), findsOneWidget);
    expect(find.text('Recorde'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4 partidas'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('2V  1E  1D'), findsOneWidget);
  });

  testWidgets('campanha apresenta progresso e bloqueio dos níveis', (
    tester,
  ) async {
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

    expect(find.text('A escalada dos nove Maias'), findsOneWidget);
    expect(find.text('1/2 vitórias • 2/3 partidas'), findsOneWidget);
    expect(find.text('Bloqueado'), findsOneWidget);
    expect(find.text('Jogar etapa'), findsOneWidget);
  });
}
