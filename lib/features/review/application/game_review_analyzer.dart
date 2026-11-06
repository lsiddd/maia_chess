import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine_ffi/stockfish_engine/stockfish_analysis.dart';
import '../../game/application/game_controller.dart';
import '../../history/domain/game_replayer.dart';
import '../domain/game_review.dart';

typedef ReviewSearch =
    Future<List<StockfishLine>> Function({
      required String fen,
      required String initialFen,
      required List<String> moves,
      required int count,
      required int movetimeMs,
      required void Function() ensureActive,
    });

final reviewAnalyzerProvider = Provider<GameReviewAnalyzer>(
  (ref) => GameReviewAnalyzer(
    ref.watch(gameControllerProvider.notifier).searchStockfishForReview,
  ),
);

class ReviewCancelledException implements Exception {
  const ReviewCancelledException();

  @override
  String toString() => 'Review cancelled.';
}

class ReviewLimitException implements Exception {
  const ReviewLimitException();

  @override
  String toString() =>
      'Full review is available for games of up to '
      '${GameReviewAnalyzer.maxFullReviewPlies} half-moves. '
      'You can still analyze individual positions.';
}

/// Stops queuing new searches and discards a result if cancelled in flight.
/// The in-flight search finishes within the engine's existing timeouts.
class ReviewRequest {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void _ensureActive() {
    if (_cancelled) throw const ReviewCancelledException();
  }
}

class GameReviewAnalyzer {
  const GameReviewAnalyzer(this._search);

  static const maxFullReviewPlies = 400;
  static const _scanMovetimeMs = 160;
  static const _positionMovetimeMs = 400;
  static const _reviewTimeout = Duration(minutes: 3);

  final ReviewSearch _search;

  Future<GameReview> analyze(
    ReplayedGame game, {
    required ReviewRequest request,
    void Function(int done, int total)? onProgress,
  }) async {
    request._ensureActive();
    if (game.ucis.length > maxFullReviewPlies) {
      throw const ReviewLimitException();
    }
    final elapsed = Stopwatch()..start();
    final positions = <ReviewPositionAnalysis>[];
    final total = game.positions.length;
    onProgress?.call(0, total);
    for (var ply = 0; ply < total; ply++) {
      positions.add(
        await _analyzePosition(
          _ReviewPosition.fromGame(game, ply),
          request: request,
          count: 3,
          movetimeMs: _scanMovetimeMs,
        ),
      );
      if (elapsed.elapsed >= _reviewTimeout) {
        throw TimeoutException('Full review exceeded its analysis time limit.');
      }
      onProgress?.call(ply + 1, total);
      request._ensureActive();
    }

    return GameReview(
      positions: positions,
      moves: [
        for (var index = 0; index < game.ucis.length; index++)
          ReviewedMove(
            ply: index + 1,
            side: game.positions[index].turn,
            uci: parseReviewMove(game.positions[index], game.ucis[index])!.uci,
            san: game.sans[index],
            before: positions[index],
            after: positions[index + 1],
          ),
      ],
    );
  }

  Future<ReviewPositionAnalysis> analyzePosition(
    ReplayedGame game,
    int ply, {
    List<String> continuation = const [],
    required ReviewRequest request,
  }) async => _analyzePosition(
    _ReviewPosition.fromGame(game, ply, continuation: continuation),
    request: request,
    count: 3,
    movetimeMs: _positionMovetimeMs,
  );

  Future<ReviewRetry> retryMove(
    ReplayedGame game,
    ReviewedMove review,
    String uci, {
    required ReviewRequest request,
  }) async {
    request._ensureActive();
    final ply = review.ply - 1;
    final position = game.positions[ply];
    final move = parseReviewMove(position, uci);
    if (move == null) throw ArgumentError.value(uci, 'uci', 'Illegal move');
    if (review.before.lines.firstOrNull?.ucis.first == move.uci) {
      return ReviewRetry(
        side: position.turn,
        best: review.before.evaluation,
        evaluation: review.before.evaluation,
        matchesBestMove: true,
      );
    }
    // Reanalyze both the best line and the attempted move at the same longer
    // budget so an alternative can pass even if the quick scan ranked it lower.
    final best = await _analyzePosition(
      _ReviewPosition.fromGame(game, ply),
      request: request,
      count: 1,
      movetimeMs: _positionMovetimeMs,
    );
    final matchesBest = best.lines.firstOrNull?.ucis.first == move.uci;
    final played = matchesBest
        ? best
        : await _analyzePosition(
            _ReviewPosition.fromGame(game, ply, continuation: [move.uci]),
            request: request,
            count: 1,
            movetimeMs: _positionMovetimeMs,
          );
    return ReviewRetry(
      side: position.turn,
      best: best.evaluation,
      evaluation: played.evaluation,
      matchesBestMove: matchesBest,
    );
  }

  Future<ReviewPositionAnalysis> _analyzePosition(
    _ReviewPosition target, {
    required ReviewRequest request,
    required int count,
    required int movetimeMs,
  }) async {
    request._ensureActive();
    final position = target.position;
    final terminal = target.terminalEvaluation;
    if (terminal != null) return ReviewPositionAnalysis(evaluation: terminal);

    final result = await _search(
      fen: position.fen,
      initialFen: target.initial.fen,
      moves: target.moves,
      count: count,
      movetimeMs: movetimeMs,
      ensureActive: request._ensureActive,
    );
    request._ensureActive();
    final primary = result.firstOrNull;
    final bestLine = primary == null || primary.rank != 1
        ? null
        : ReviewLine.fromStockfish(position, primary);
    if (bestLine == null) {
      // An older device may not finish its first MultiPV iteration within
      // the scan budget. Give it one longer single-line search.
      if (movetimeMs < _positionMovetimeMs) {
        return _analyzePosition(
          target,
          request: request,
          count: 1,
          movetimeMs: _positionMovetimeMs,
        );
      }
      throw StateError('Stockfish did not return a legal evaluation line.');
    }
    return ReviewPositionAnalysis(
      evaluation: bestLine.evaluation,
      lines: [
        bestLine,
        for (final line in result.skip(1))
          ?ReviewLine.fromStockfish(position, line),
      ],
    );
  }
}

/// Reversible history ending at a position, including any trial moves. Earlier
/// moves cannot affect repetition after a pawn move or capture.
class _ReviewPosition {
  _ReviewPosition(this._positions, this.moves);

  factory _ReviewPosition.fromGame(
    ReplayedGame game,
    int ply, {
    List<String> continuation = const [],
  }) {
    var position = game.positions[ply];
    final branchPositions = [position];
    final branchMoves = <String>[];
    for (final uci in continuation) {
      final move = parseReviewMove(position, uci);
      if (move == null) {
        throw ArgumentError.value(uci, 'continuation', 'Illegal move');
      }
      position = position.playUnchecked(move) as Chess;
      branchPositions.add(position);
      branchMoves.add(move.uci);
    }
    if (position.halfmoves >= 100) {
      // This is already a draw under the app's fifty-move rule. Avoid
      // walking an unbounded sequence of quiet moves from an imported PGN.
      return _ReviewPosition([position], []);
    }
    final start = math.max(0, ply + branchMoves.length - position.halfmoves);
    if (start >= ply) {
      return _ReviewPosition(
        branchPositions.sublist(start - ply),
        branchMoves.sublist(start - ply),
      );
    }
    return _ReviewPosition(
      [...game.positions.getRange(start, ply), ...branchPositions],
      [
        for (var index = start; index < ply; index++)
          parseReviewMove(game.positions[index], game.ucis[index])!.uci,
        ...branchMoves,
      ],
    );
  }

  final List<Chess> _positions;
  final List<String> moves;

  Chess get initial => _positions.first;
  Chess get position => _positions.last;

  ReviewEvaluation? get terminalEvaluation {
    if (position.isCheckmate) return ReviewEvaluation.checkmate(position.turn);
    if (position.isGameOver || position.halfmoves >= 100 || _isThreefold) {
      return const ReviewEvaluation.centipawns(0);
    }
    return null;
  }

  bool get _isThreefold {
    if (_positions.length < 9) return false;
    final key = _repetitionKey(position);
    var previousMatches = 0;
    for (var index = _positions.length - 3; index >= 0; index -= 2) {
      if (_repetitionKey(_positions[index]) == key && ++previousMatches == 2) {
        return true;
      }
    }
    return false;
  }

  String _repetitionKey(Chess position) =>
      position.fen.split(' ').take(4).join(' ');
}
