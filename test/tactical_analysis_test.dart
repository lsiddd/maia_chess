import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/tactics/domain/tactical_analysis.dart';

Chess position(String fen) => Chess.fromSetup(Setup.parseFen(fen));

void main() {
  test(
    'identifies attacked pieces on both sides, including defended pieces',
    () {
      final board = position('4k3/8/2p5/3p4/4P3/5P2/8/4K3 w - - 0 1');
      expect(attackedPieces(board), {Square.e4, Square.d5});
      expect(attackedPieces(Chess.initial), isEmpty);
    },
  );

  test('pawns attack diagonally, never the piece blocking their advance', () {
    final board = position('4k3/8/8/4p3/4P3/8/8/4K3 w - - 0 1');
    expect(attackedPieces(board), isEmpty);
  });

  test('respects blockers and includes attacks by pinned pieces', () {
    final board = position('4k3/8/8/8/8/3p4/4N3/4K2r w - - 0 1');
    expect(attackedPieces(board), containsAll([Square.e2, Square.e1]));
    final pinned = position('4r1k1/8/8/8/8/2p5/4N3/4K3 w - - 0 1');
    expect(attackedPieces(pinned), contains(Square.c3));
    final blocked = position('4r1k1/4p3/8/8/8/8/4N3/4K3 w - - 0 1');
    expect(attackedPieces(blocked), isNot(contains(Square.e2)));
  });

  test(
    'marks the victim of legal en passant but excludes pinned en passant',
    () {
      final board = position('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
      expect(attackedPieces(board), contains(Square.d5));
      final pinned = position('4r1k1/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
      expect(attackedPieces(pinned), isNot(contains(Square.d5)));
    },
  );

  test('simulated turn preserves board and castling and clears en passant', () {
    final original = position('r3k2r/8/8/3pP3/8/8/8/R3K2R w KQkq d6 0 10');
    final simulated = opponentThreatPosition(original);
    expect(simulated.turn, Side.black);
    expect(simulated.board, original.board);
    expect(simulated.epSquare, isNull);
    expect(simulated.fen.split(' ')[2], 'KQkq');
    expect(original.turn, Side.white);
    expect(original.epSquare, Square.d6);
    expect(opponentThreatPosition(simulated).turn, Side.white);
  });

  test('does not send an impossible position to the engine while in check', () {
    final board = position('4r1k1/8/8/8/8/8/8/4K3 w - - 0 1');
    expect(() => opponentThreatPosition(board), throwsStateError);
  });

  test(
    'converts promotion and mate to SAN and preserves the opponent score',
    () {
      final board = position('7k/P7/6K1/8/8/8/8/8 w - - 0 1');
      final result = ThreatResult.fromLines(board, [
        StockfishLine(rank: 1, depth: 8, moves: ['a7a8q'], mate: 1),
      ]);
      expect(result.threats.single.san, 'a8=Q#');
      expect(result.threats.single.scoreLabel, 'Mate in 1');
      expect(
        () => ThreatResult.fromLines(board, [
          StockfishLine(rank: 1, depth: 8, moves: ['a7a5'], centipawns: 0),
        ]),
        throwsA(isA<PlayException>()),
      );
    },
  );

  test('parser recognises cp/mate scores and ignores bounds and messages', () {
    final cp = StockfishLine.parse(
      'info depth 12 seldepth 18 multipv 2 score cp -35 nodes 10 pv e7e5 g1f3',
    )!;
    expect(cp.rank, 2);
    expect(cp.depth, 12);
    expect(cp.centipawns, -35);
    expect(cp.moves, ['e7e5', 'g1f3']);
    expect(
      StockfishLine.parse('info depth 9 multipv 1 score mate -3 pv e7e5')!.mate,
      -3,
    );
    for (final line in [
      'bestmove e7e5',
      'info string hello',
      'info depth 3 score cp 5',
      'info depth 3 score cp 5 lowerbound pv e7e5',
      'info depth 3 score cp 5 upperbound pv e7e5',
      'info depth x score cp 5 pv e7e5',
    ]) {
      expect(StockfishLine.parse(line), isNull, reason: line);
    }
  });

  test('MultiPV keeps the latest complete depth without mixing ranks', () {
    final collector = StockfishAnalysisCollector(3);
    for (var rank = 1; rank <= 3; rank++) {
      collector.add(
        'info depth 8 multipv $rank score cp 20 pv '
        '${['e7e5', 'd7d5', 'g8f6'][rank - 1]}',
      );
    }
    collector.add('info depth 9 multipv 1 score cp 35 pv d7d5');
    expect(collector.lines.map((line) => line.depth), [8, 8, 8]);
    collector.add('info depth 9 multipv 2 score cp 20 pv e7e5');
    collector.add('info depth 9 multipv 3 score mate -4 pv g8f6');
    expect(collector.lines.map((line) => line.depth), [9, 9, 9]);
    expect(collector.lines.map((line) => line.moves.first), [
      'd7d5',
      'e7e5',
      'g8f6',
    ]);
  });

  test(
    'MultiPV supports fewer than three variations and discards duplicates',
    () {
      final collector = StockfishAnalysisCollector(3);
      collector.add('info depth 8 multipv 1 score cp 20 pv e7e5');
      collector.add('info depth 8 multipv 2 score cp 15 pv d7d5');
      collector.add('info depth 9 multipv 1 score cp 30 pv e7e5');
      collector.add('info depth 9 multipv 2 score cp 10 pv e7e5');
      expect(collector.lines.map((line) => line.depth), [8, 8]);
    },
  );
}
