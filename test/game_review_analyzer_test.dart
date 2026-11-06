import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/review/application/game_review_analyzer.dart';
import 'package:maia_chess/features/review/domain/game_review.dart';

void main() {
  test(
    'reviews all positions and scores both sides from White’s perspective',
    () async {
      final game = _game(['e2e4', 'e7e5']);
      final search = _SearchFake((call) {
        return switch (game.positions.indexWhere(
          (pos) => pos.fen == call.fen,
        )) {
          0 => [_line('d2d4', 70)],
          1 => [_line('c7c5', 110)],
          _ => [_line('g1f3', 260)],
        };
      });
      final progress = <(int, int)>[];

      final review = await GameReviewAnalyzer(search.run).analyze(
        game,
        request: ReviewRequest(),
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
      expect(review.positions.map((pos) => pos.evaluation.centipawns), [
        70,
        -110,
        260,
      ]);
      expect(review.moves.map((move) => move.side), [Side.white, Side.black]);
      expect(review.moves.map((move) => move.quality), [
        ReviewMoveQuality.mistake,
        ReviewMoveQuality.blunder,
      ]);
      expect(review.keyMoments.map((move) => move.ply), [1, 2]);
      expect(review.summary(Side.white).averageCentipawnLoss, 180);
      expect(review.summary(Side.black).averageCentipawnLoss, 370);
      expect(
        review.summary(Side.white).accuracy,
        greaterThan(review.summary(Side.black).accuracy!),
      );
    },
  );

  test(
    'uses the same-depth engine alternative to grade a played move',
    () async {
      final game = _game(['e2e4']);
      final search = _SearchFake((call) {
        return call.fen == game.positions.first.fen
            ? [_line('d2d4', 50), _line('e2e4', 45, rank: 2)]
            : [_line('e7e5', 600)];
      });

      final review = await GameReviewAnalyzer(
        search.run,
      ).analyze(game, request: ReviewRequest());

      expect(review.moves.single.quality, ReviewMoveQuality.excellent);
      expect(review.moves.single.centipawnLoss, 5);
      expect(review.moves.single.playedEvaluation.centipawns, 45);
      expect(review.summary(Side.black).accuracy, isNull);
      expect(review.keyMoments, isEmpty);
    },
  );

  test(
    'uses the exact terminal result without asking the engine for a move',
    () async {
      final game = _game(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      final search = _SearchFake((call) {
        final ply = game.positions.indexWhere((pos) => pos.fen == call.fen);
        final response = switch (ply) {
          0 => _line('e2e4', 30),
          1 => _line('e7e5', 95),
          2 => _line('d2d4', -40),
          3 => StockfishLine(rank: 1, depth: 14, moves: ['d8h4'], mate: 1),
          _ => throw StateError('A checkmate position has no legal move.'),
        };
        return [response];
      });

      final review = await GameReviewAnalyzer(
        search.run,
      ).analyze(game, request: ReviewRequest());

      expect(search.calls, hasLength(4));
      expect(review.moves.last.quality, ReviewMoveQuality.best);
      expect(review.moves.last.winPercentLoss, 0);
      expect(review.positions[3].evaluation.mate, -1);
      expect(review.positions.last.evaluation.checkmatedSide, Side.white);
      expect(review.positions.last.evaluation.whiteWinPercent, 0);
      expect(review.positions.last.lines, isEmpty);
    },
  );

  test(
    'preserves reversible history and recognizes repetition in a trial line',
    () async {
      final game = _game([
        'e2e4',
        'e7e5',
        'g1f3',
        'g8f6',
        'f3g1',
        'f6g8',
        'g1f3',
        'g8f6',
        'f3g1',
      ]);
      final search = _SearchFake((_) => [_line('f6g8', 50)]);
      final analyzer = GameReviewAnalyzer(search.run);

      await analyzer.analyzePosition(game, 9, request: ReviewRequest());

      expect(search.calls.single.initialFen, game.positions[2].fen);
      expect(search.calls.single.moves, game.ucis.skip(2).toList());

      final draw = await analyzer.analyzePosition(
        game,
        9,
        continuation: ['f6g8'],
        request: ReviewRequest(),
      );

      expect(search.calls, hasLength(1));
      expect(draw.evaluation.centipawns, 0);
      expect(draw.lines, isEmpty);
    },
  );

  test(
    'normalizes castling from saved moves and PVs and retains legal SAN',
    () async {
      final initial = Chess.fromSetup(
        Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
      );
      final game = _game(['e1h1'], initial: initial);
      final search = _SearchFake((call) {
        return call.fen == initial.fen
            ? [
                StockfishLine(
                  rank: 1,
                  depth: 12,
                  moves: ['e1g1', 'e8a8', 'a1e1'],
                  centipawns: 40,
                ),
              ]
            : [_line('e8c8', -30)];
      });
      final review = await GameReviewAnalyzer(
        search.run,
      ).analyze(game, request: ReviewRequest());

      expect(search.calls.last.moves, ['e1g1']);
      expect(review.positions.first.lines.first.ucis, ['e1g1', 'e8c8', 'a1e1']);
      expect(review.positions.first.lines.first.sans, ['O-O', 'O-O-O', 'Rae1']);
      expect(review.moves.single.quality, ReviewMoveQuality.best);
    },
  );

  test('accepts a strong alternative and rejects a weak retry', () async {
    final game = _game(['e2e4']);
    final search = _SearchFake((call) {
      final position = Chess.fromSetup(Setup.parseFen(call.fen));
      return [
        switch (position.turn) {
          Side.white => _line('d2d4', 50),
          Side.black
              when position.board.pieceAt(Square.c4)?.role == Role.pawn =>
            _line('e7e5', -30),
          Side.black => _line('e7e5', 180),
        },
      ];
    });
    final analyzer = GameReviewAnalyzer(search.run);
    final review = await analyzer.analyze(game, request: ReviewRequest());

    final alternative = await analyzer.retryMove(
      game,
      review.moves.single,
      'c2c4',
      request: ReviewRequest(),
    );
    final weak = await analyzer.retryMove(
      game,
      review.moves.single,
      'f2f3',
      request: ReviewRequest(),
    );

    expect(alternative.acceptable, isTrue);
    expect(weak.acceptable, isFalse);
    expect(search.calls.last.count, 1);
    expect(
      search.calls.last.movetimeMs,
      greaterThan(search.calls.first.movetimeMs),
    );
  });

  test(
    'cancellation discards an in-flight result and never queues the next position',
    () async {
      final game = _game(['e2e4', 'e7e5']);
      final result = Completer<List<StockfishLine>>();
      final search = _SearchFake((_) => result.future);
      final request = ReviewRequest();
      final progress = <int>[];
      final pending = GameReviewAnalyzer(search.run).analyze(
        game,
        request: request,
        onProgress: (done, _) => progress.add(done),
      );
      final assertion = expectLater(
        pending,
        throwsA(isA<ReviewCancelledException>()),
      );
      request.cancel();
      result.complete([_line('e2e4', 50)]);

      await assertion;
      expect(search.calls, hasLength(1));
      expect(progress, [0]);
    },
  );

  test('retries a scan that has no legal engine line once', () async {
    final game = _game([]);
    final search = _SearchFake(
      (call) => call.count == 3 ? [] : [_line('e2e4', 35)],
    );
    final review = await GameReviewAnalyzer(
      search.run,
    ).analyze(game, request: ReviewRequest());

    expect(search.calls.map((call) => call.count), [3, 1]);
    expect(review.positions.single.lines.single.sans, ['e4']);
  });

  test(
    'rejects full review of very long games before starting Stockfish',
    () async {
      final game = ReplayedGame(
        positions: [Chess.initial],
        sans: [],
        ucis: List.filled(GameReviewAnalyzer.maxFullReviewPlies + 1, 'a2a3'),
      );
      final search = _SearchFake(
        (_) => throw StateError('Unexpected engine call'),
      );

      await expectLater(
        GameReviewAnalyzer(search.run).analyze(game, request: ReviewRequest()),
        throwsA(isA<ReviewLimitException>()),
      );
      expect(search.calls, isEmpty);
    },
  );
}

ReplayedGame _game(List<String> ucis, {Chess? initial}) {
  var position = initial ?? Chess.initial;
  final positions = [position];
  final sans = <String>[];
  for (final uci in ucis) {
    final (after, san) = position.makeSan(Move.parse(uci)!);
    position = after as Chess;
    positions.add(position);
    sans.add(san);
  }
  return ReplayedGame(positions: positions, sans: sans, ucis: ucis);
}

StockfishLine _line(String uci, int cp, {int rank = 1}) =>
    StockfishLine(rank: rank, depth: 12, moves: [uci], centipawns: cp);

typedef _SearchCall = ({
  String fen,
  String initialFen,
  List<String> moves,
  int count,
  int movetimeMs,
});

class _SearchFake {
  _SearchFake(this._response);

  final FutureOr<List<StockfishLine>> Function(_SearchCall) _response;
  final calls = <_SearchCall>[];

  Future<List<StockfishLine>> run({
    required String fen,
    required String initialFen,
    required List<String> moves,
    required int count,
    required int movetimeMs,
    required void Function() ensureActive,
  }) async {
    ensureActive();
    final call = (
      fen: fen,
      initialFen: initialFen,
      moves: moves,
      count: count,
      movetimeMs: movetimeMs,
    );
    calls.add(call);
    return _response(call);
  }
}
