import 'dart:math' as math;

/// Resultado de uma partida elegível, sempre do ponto de vista do jogador.
enum PlayerGameOutcome { win, loss, draw }

/// Projeção mínima de uma partida usada pelos cálculos da Fase 5.
class EvaluatedGameSummary {
  const EvaluatedGameSummary({
    required this.gameId,
    required this.completedAtUtc,
    required this.levelRating,
    required this.outcome,
    required this.campaignMode,
  });

  final String gameId;
  final DateTime completedAtUtc;
  final int levelRating;
  final PlayerGameOutcome outcome;
  final bool campaignMode;
}

class RatingPoint {
  const RatingPoint({
    required this.gameId,
    required this.recordedAtUtc,
    required this.value,
  });

  final String gameId;
  final DateTime recordedAtUtc;
  final double value;
}

class LevelResults {
  const LevelResults({this.wins = 0, this.losses = 0, this.draws = 0});

  final int wins;
  final int losses;
  final int draws;

  int get total => wins + losses + draws;

  LevelResults add(PlayerGameOutcome outcome) => switch (outcome) {
    PlayerGameOutcome.win => LevelResults(
      wins: wins + 1,
      losses: losses,
      draws: draws,
    ),
    PlayerGameOutcome.loss => LevelResults(
      wins: wins,
      losses: losses + 1,
      draws: draws,
    ),
    PlayerGameOutcome.draw => LevelResults(
      wins: wins,
      losses: losses,
      draws: draws + 1,
    ),
  };
}

class PlayerStatsSnapshot {
  const PlayerStatsSnapshot({
    required this.estimatedRating,
    required this.ratingHistory,
    required this.resultsByLevel,
    required this.currentStreak,
    required this.recordStreak,
    required this.evaluatedGames,
  });

  factory PlayerStatsSnapshot.empty() => const PlayerStatsSnapshot(
    estimatedRating: PlayerStatsCalculator.initialRating,
    ratingHistory: [],
    resultsByLevel: {},
    currentStreak: 0,
    recordStreak: 0,
    evaluatedGames: 0,
  );

  final double estimatedRating;
  final List<RatingPoint> ratingHistory;
  final Map<int, LevelResults> resultsByLevel;
  final int currentStreak;
  final int recordStreak;
  final int evaluatedGames;

  PlayerStatsSnapshot copyWith({
    double? estimatedRating,
    List<RatingPoint>? ratingHistory,
  }) {
    return PlayerStatsSnapshot(
      estimatedRating: estimatedRating ?? this.estimatedRating,
      ratingHistory: ratingHistory ?? this.ratingHistory,
      resultsByLevel: resultsByLevel,
      currentStreak: currentStreak,
      recordStreak: recordStreak,
      evaluatedGames: evaluatedGames,
    );
  }
}

class PlayerStatsCalculator {
  const PlayerStatsCalculator();

  static const double initialRating = 1500;
  static const double kFactor = 32;
  static const double minimumRating = 600;
  static const double maximumRating = 2400;

  PlayerStatsSnapshot calculate(Iterable<EvaluatedGameSummary> games) {
    final ordered = games.toList(growable: false)
      ..sort((a, b) {
        final byDate = a.completedAtUtc.compareTo(b.completedAtUtc);
        return byDate != 0 ? byDate : a.gameId.compareTo(b.gameId);
      });

    var rating = initialRating;
    var currentStreak = 0;
    var recordStreak = 0;
    final history = <RatingPoint>[];
    final results = <int, LevelResults>{};

    for (final game in ordered) {
      final score = switch (game.outcome) {
        PlayerGameOutcome.win => 1.0,
        PlayerGameOutcome.draw => 0.5,
        PlayerGameOutcome.loss => 0.0,
      };
      final expected =
          1 / (1 + math.pow(10, (game.levelRating - rating) / 400));
      rating = (rating + kFactor * (score - expected)).clamp(
        minimumRating,
        maximumRating,
      );
      history.add(
        RatingPoint(
          gameId: game.gameId,
          recordedAtUtc: game.completedAtUtc.toUtc(),
          value: rating,
        ),
      );

      results[game.levelRating] =
          (results[game.levelRating] ?? const LevelResults()).add(game.outcome);
      if (game.outcome == PlayerGameOutcome.win) {
        currentStreak++;
        recordStreak = math.max(recordStreak, currentStreak);
      } else {
        currentStreak = 0;
      }
    }

    return PlayerStatsSnapshot(
      estimatedRating: rating,
      ratingHistory: List.unmodifiable(history),
      resultsByLevel: Map.unmodifiable(results),
      currentStreak: currentStreak,
      recordStreak: recordStreak,
      evaluatedGames: ordered.length,
    );
  }
}

class CampaignWindowResult {
  const CampaignWindowResult({
    required this.wins,
    required this.games,
    required this.qualified,
  });

  final int wins;
  final int games;
  final bool qualified;
}

/// Avalia todas as janelas móveis em ordem cronológica. Quando uma janela
/// atinge o requisito, a conquista permanece verdadeira no restante do
/// histórico.
CampaignWindowResult evaluateCampaignWindow(
  Iterable<PlayerGameOutcome> outcomes, {
  required int winsRequired,
  required int windowSize,
}) {
  if (winsRequired <= 0 || windowSize < winsRequired) {
    throw ArgumentError(
      'Regra de campanha inválida: $winsRequired/$windowSize',
    );
  }

  final window = <PlayerGameOutcome>[];
  for (final outcome in outcomes) {
    window.add(outcome);
    if (window.length > windowSize) window.removeAt(0);
    final wins = window.where((item) => item == PlayerGameOutcome.win).length;
    if (wins >= winsRequired) {
      return CampaignWindowResult(
        wins: winsRequired,
        games: window.length,
        qualified: true,
      );
    }
  }

  return CampaignWindowResult(
    wins: window.where((item) => item == PlayerGameOutcome.win).length,
    games: window.length,
    qualified: false,
  );
}
