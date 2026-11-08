import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/stats/domain/player_stats.dart';

void main() {
  group('PlayerStatsCalculator', () {
    test('applies Elo chronologically and calculates the winning streak', () {
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

    test('a draw resets the streak and scores half a point for rating', () {
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
}
