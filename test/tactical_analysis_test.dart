import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/tactics/domain/tactical_analysis.dart';

Chess position(String fen) => Chess.fromSetup(Setup.parseFen(fen));

void main() {
  test('identifica peças atacadas dos dois lados, inclusive defendidas', () {
    final board = position('4k3/8/2p5/3p4/4P3/5P2/8/4K3 w - - 0 1');
    expect(attackedPieces(board), {Square.e4, Square.d5});
    expect(attackedPieces(Chess.initial), isEmpty);
  });

  test('peões atacam diagonais, nunca a peça bloqueando seu avanço', () {
    final board = position('4k3/8/8/4p3/4P3/8/8/4K3 w - - 0 1');
    expect(attackedPieces(board), isEmpty);
  });

  test('respeita bloqueios e inclui ataques de peças cravadas', () {
    final board = position('4k3/8/8/8/8/3p4/4N3/4K2r w - - 0 1');
    expect(attackedPieces(board), containsAll([Square.e2, Square.e1]));
    final pinned = position('4r1k1/8/8/8/8/2p5/4N3/4K3 w - - 0 1');
    expect(attackedPieces(pinned), contains(Square.c3));
    final blocked = position('4r1k1/4p3/8/8/8/8/4N3/4K3 w - - 0 1');
    expect(attackedPieces(blocked), isNot(contains(Square.e2)));
  });

  test('marca vítima de en passant legal mas não en passant cravado', () {
    final board = position('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
    expect(attackedPieces(board), contains(Square.d5));
    final pinned = position('4r1k1/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
    expect(attackedPieces(pinned), isNot(contains(Square.d5)));
  });

  test('simular turno preserva tabuleiro e roque, limpa en passant', () {
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

  test('não envia ao motor uma posição impossível quando há xeque', () {
    final board = position('4r1k1/8/8/8/8/8/8/4K3 w - - 0 1');
    expect(() => opponentThreatPosition(board), throwsStateError);
  });

  test('converte promoção e mate em SAN e mantém avaliação do adversário', () {
    final board = position('7k/P7/6K1/8/8/8/8/8 w - - 0 1');
    final result = ThreatResult.fromLines(board, [
      StockfishLine(rank: 1, depth: 8, moves: ['a7a8q'], mate: 1),
    ]);
    expect(result.threats.single.san, 'a8=Q#');
    expect(result.threats.single.scoreLabel, 'Mate em 1');
    expect(
      () => ThreatResult.fromLines(board, [
        StockfishLine(rank: 1, depth: 8, moves: ['a7a5'], centipawns: 0),
      ]),
      throwsA(isA<PlayException>()),
    );
  });

  test('parser reconhece score cp/mate e ignora bounds e mensagens', () {
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

  test('MultiPV mantém última profundidade completa sem misturar ranks', () {
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

  test('MultiPV suporta menos de três variantes e descarta duplicatas', () {
    final collector = StockfishAnalysisCollector(3);
    collector.add('info depth 8 multipv 1 score cp 20 pv e7e5');
    collector.add('info depth 8 multipv 2 score cp 15 pv d7d5');
    collector.add('info depth 9 multipv 1 score cp 30 pv e7e5');
    collector.add('info depth 9 multipv 2 score cp 10 pv e7e5');
    expect(collector.lines.map((line) => line.depth), [8, 8]);
  });
}
