import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

import '../../../engine_ffi/stockfish_engine/stockfish_analysis.dart';

/// An evaluation from White's perspective, including when Black is to move.
class ReviewEvaluation {
  const ReviewEvaluation.centipawns(int value)
    : centipawns = value,
      mate = null,
      checkmatedSide = null;

  const ReviewEvaluation.mate(int value)
    : centipawns = null,
      mate = value,
      checkmatedSide = null;

  const ReviewEvaluation.checkmate(Side side)
    : centipawns = null,
      mate = null,
      checkmatedSide = side;

  factory ReviewEvaluation.fromStockfish(Side turn, StockfishLine line) {
    final sign = turn == Side.white ? 1 : -1;
    final mate = line.mate;
    return mate == null
        ? ReviewEvaluation.centipawns(line.centipawns! * sign)
        : ReviewEvaluation.mate(mate * sign);
  }

  final int? centipawns;
  final int? mate;
  final Side? checkmatedSide;

  /// A capped equivalent for calculating average centipawn loss.
  int get comparableCentipawns {
    if (checkmatedSide case final side?) {
      return side == Side.white ? -1000 : 1000;
    }
    if (mate case final distance?) return distance.isNegative ? -1000 : 1000;
    return centipawns!.clamp(-1000, 1000);
  }

  /// Lichess's published conversion from centipawns to winning chances.
  /// https://lichess.org/page/accuracy
  double get whiteWinPercent {
    if (checkmatedSide case final side?) return side == Side.white ? 0 : 100;
    if (mate case final distance?) return distance.isNegative ? 0 : 100;
    return 100 / (1 + math.exp(-0.00368208 * comparableCentipawns));
  }

  double winPercentFor(Side side) =>
      side == Side.white ? whiteWinPercent : 100 - whiteWinPercent;

  String get display {
    if (checkmatedSide case final side?) {
      return side == Side.white ? 'Black wins by mate' : 'White wins by mate';
    }
    if (mate case final distance?) {
      return '${distance.isNegative ? '-' : '+'}M${distance.abs()}';
    }
    final score = centipawns! / 100;
    return '${score > 0 ? '+' : ''}${score.toStringAsFixed(2)}';
  }
}

class ReviewLine {
  ReviewLine({
    required this.evaluation,
    required List<String> ucis,
    required List<String> sans,
  }) : assert(ucis.isNotEmpty && ucis.length == sans.length),
       ucis = List.unmodifiable(ucis),
       sans = List.unmodifiable(sans);

  static ReviewLine? fromStockfish(Chess position, StockfishLine line) {
    final evaluation = ReviewEvaluation.fromStockfish(position.turn, line);
    final ucis = <String>[];
    final sans = <String>[];
    for (final uci in line.moves.take(16)) {
      final move = parseReviewMove(position, uci);
      if (move == null) break;
      final (next, san) = position.makeSan(move);
      ucis.add(move.uci);
      sans.add(san);
      position = next as Chess;
    }
    return ucis.isEmpty
        ? null
        : ReviewLine(evaluation: evaluation, ucis: ucis, sans: sans);
  }

  final ReviewEvaluation evaluation;
  final List<String> ucis;
  final List<String> sans;
}

class ReviewPositionAnalysis {
  ReviewPositionAnalysis({
    required this.evaluation,
    List<ReviewLine> lines = const [],
  }) : lines = List.unmodifiable(lines);

  final ReviewEvaluation evaluation;
  final List<ReviewLine> lines;
}

enum ReviewMoveQuality {
  best('Best'),
  excellent('Excellent'),
  good('Good'),
  inaccuracy('Inaccuracy'),
  mistake('Mistake'),
  blunder('Blunder'),
  missed('Missed win');

  const ReviewMoveQuality(this.label);

  final String label;

  bool get isMistake => switch (this) {
    inaccuracy || mistake || blunder || missed => true,
    best || excellent || good => false,
  };
}

class ReviewedMove {
  const ReviewedMove({
    required this.ply,
    required this.side,
    required this.uci,
    required this.san,
    required this.before,
    required this.after,
  });

  /// The position reached by this move, one-based.
  final int ply;
  final Side side;
  final String uci;
  final String san;
  final ReviewPositionAnalysis before;
  final ReviewPositionAnalysis after;

  bool get _isEngineMove =>
      before.lines.isNotEmpty && before.lines.first.ucis.first == uci;

  /// Prefer an evaluation at the same search depth when the played move is
  /// among the engine's alternatives. Use the resulting position otherwise.
  ReviewEvaluation get playedEvaluation {
    if (after.lines.isEmpty) return after.evaluation;
    for (final line in before.lines.skip(1)) {
      if (line.ucis.first == uci) return line.evaluation;
    }
    return after.evaluation;
  }

  double get winPercentLoss => _isEngineMove
      ? 0
      : _winPercentLoss(side, before.evaluation, playedEvaluation);

  int get centipawnLoss {
    if (_isEngineMove) return 0;
    final whiteDifference =
        before.evaluation.comparableCentipawns -
        playedEvaluation.comparableCentipawns;
    return math.max(0, side == Side.white ? whiteDifference : -whiteDifference);
  }

  // Use winning-chance losses instead of fixed centipawn losses, which overstate
  // mistakes in positions where the outcome is already practically decided.
  ReviewMoveQuality get quality {
    if (_isEngineMove) return ReviewMoveQuality.best;
    final loss = winPercentLoss;
    if (loss <= 2) return ReviewMoveQuality.excellent;
    if (loss <= 5) return ReviewMoveQuality.good;
    if (loss <= 10) return ReviewMoveQuality.inaccuracy;
    final remainingChance = playedEvaluation.winPercentFor(side);
    if (before.evaluation.winPercentFor(side) >= 75 &&
        remainingChance >= 42 &&
        remainingChance < 58) {
      return ReviewMoveQuality.missed;
    }
    return loss <= 20 ? ReviewMoveQuality.mistake : ReviewMoveQuality.blunder;
  }

  double get accuracy =>
      (103.1668 * math.exp(-0.04354 * winPercentLoss) - 3.1669).clamp(
        0.0,
        100.0,
      );
}

class ReviewSideSummary {
  ReviewSideSummary({
    required this.accuracy,
    required this.averageCentipawnLoss,
    required Map<ReviewMoveQuality, int> counts,
  }) : counts = Map.unmodifiable(counts);

  final double? accuracy;
  final double? averageCentipawnLoss;
  final Map<ReviewMoveQuality, int> counts;
}

class GameReview {
  GameReview({
    required List<ReviewedMove> moves,
    required List<ReviewPositionAnalysis> positions,
  }) : assert(positions.length == moves.length + 1),
       moves = List.unmodifiable(moves),
       positions = List.unmodifiable(positions) {
    keyMoments = List.unmodifiable(
      moves.where((move) => move.quality.isMistake),
    );
    _summaries = {
      Side.white: _summarize(Side.white),
      Side.black: _summarize(Side.black),
    };
  }

  final List<ReviewedMove> moves;
  final List<ReviewPositionAnalysis> positions;
  late final List<ReviewedMove> keyMoments;
  late final Map<Side, ReviewSideSummary> _summaries;

  ReviewSideSummary summary(Side side) => _summaries[side]!;

  ReviewSideSummary _summarize(Side side) {
    final ownMoves = moves.where((move) => move.side == side).toList();
    final counts = {for (final quality in ReviewMoveQuality.values) quality: 0};
    if (ownMoves.isEmpty) {
      return ReviewSideSummary(
        accuracy: null,
        averageCentipawnLoss: null,
        counts: counts,
      );
    }
    final window = (moves.length ~/ 10).clamp(2, 8);
    var weightedAccuracy = 0.0;
    var totalWeight = 0.0;
    var reciprocalAccuracy = 0.0;
    var centipawnLoss = 0;
    var hasZeroAccuracy = false;
    for (final move in ownMoves) {
      final weight = _volatility(move.ply, window);
      final accuracy = move.accuracy;
      weightedAccuracy += accuracy * weight;
      totalWeight += weight;
      if (accuracy == 0) {
        hasZeroAccuracy = true;
      } else {
        reciprocalAccuracy += 1 / accuracy;
      }
      centipawnLoss += move.centipawnLoss;
      counts.update(move.quality, (count) => count + 1);
    }
    final harmonic = hasZeroAccuracy
        ? 0.0
        : ownMoves.length / reciprocalAccuracy;
    return ReviewSideSummary(
      accuracy: (weightedAccuracy / totalWeight + harmonic) / 2,
      averageCentipawnLoss: centipawnLoss / ownMoves.length,
      counts: counts,
    );
  }

  // Blend a volatility-weighted average with a harmonic mean as described in
  // Lichess's accuracy guide. The window is centered on the reviewed move.
  double _volatility(int ply, int size) {
    final start = (ply - (size + 1) ~/ 2).clamp(0, positions.length - size);
    final values = positions
        .skip(start)
        .take(size)
        .map((position) => position.evaluation.whiteWinPercent);
    final mean = values.reduce((a, b) => a + b) / size;
    final variance =
        values
            .map((value) => math.pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        size;
    return math.sqrt(variance).clamp(0.5, 12.0);
  }
}

class ReviewRetry {
  ReviewRetry({
    required Side side,
    required ReviewEvaluation best,
    required this.evaluation,
    required bool matchesBestMove,
  }) : winPercentLoss = matchesBestMove
           ? 0
           : _winPercentLoss(side, best, evaluation);

  final ReviewEvaluation evaluation;
  final double winPercentLoss;

  bool get acceptable => winPercentLoss <= 5;
}

double _winPercentLoss(
  Side side,
  ReviewEvaluation before,
  ReviewEvaluation after,
) => math.max(0, before.winPercentFor(side) - after.winPercentFor(side));

/// Use standard UCI king destinations for both stored moves and engine PVs.
/// Dartchess also accepts king-to-rook castling, which may be stored in PGNs.
NormalMove? parseReviewMove(Chess position, String uci) {
  final move = Move.parse(uci);
  if (move is! NormalMove || !position.isLegal(move)) return null;
  final normalized = position.normalizeMove(move) as NormalMove;
  if (position.board.pieceAt(normalized.from)?.role != Role.king ||
      position.board.pieceAt(normalized.to)?.color != position.turn) {
    return normalized;
  }
  final side = normalized.to > normalized.from
      ? CastlingSide.king
      : CastlingSide.queen;
  return NormalMove(from: move.from, to: kingCastlesTo(position.turn, side));
}
