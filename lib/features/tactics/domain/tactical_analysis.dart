import 'package:dartchess/dartchess.dart';

import '../../../engine_ffi/stockfish_engine/stockfish_analysis.dart';

/// Geometric attacks, including defended pieces and attacks by pinned pieces.
/// Only occupied targets are highlighted; en passant also marks its victim.
Set<Square> attackedPieces(Chess position) {
  final board = position.board;
  final attacked = <Square>{};
  for (final square in board.occupied.squares) {
    final piece = board.pieceAt(square)!;
    if (board.attacksTo(square, piece.color.opposite).isNotEmpty) {
      attacked.add(square);
    }
  }
  final ep = position.epSquare;
  if (ep != null) {
    for (final entry in position.legalMoves.entries) {
      if (board.pieceAt(entry.key)?.role == Role.pawn && entry.value.has(ep)) {
        attacked.add(Square.fromCoords(ep.file, entry.key.rank));
      }
    }
  }
  return Set.unmodifiable(attacked);
}

/// A null move is only valid outside check. Clear the expired en passant
/// right, preserve castling rights, and keep this copy out of game history.
Chess opponentThreatPosition(Chess position) {
  if (position.isCheck) {
    throw StateError('Saia do xeque antes de analisar as ameaças.');
  }
  return Chess.fromSetup(
    Setup.parseFen(
      position.copyWith(turn: position.turn.opposite, epSquare: null).fen,
    ),
  );
}

class OpponentThreat {
  const OpponentThreat({
    required this.san,
    required this.move,
    required this.line,
  });

  final String san;
  final NormalMove move;
  final StockfishLine line;

  String get scoreLabel {
    final mate = line.mate;
    if (mate != null) {
      return mate > 0 ? 'Mate em $mate' : 'Sofre mate em ${mate.abs()}';
    }
    final score = line.centipawns! / 100;
    return '${score >= 0 ? '+' : ''}${score.toStringAsFixed(2)}';
  }
}

class ThreatResult {
  ThreatResult({required this.position, required List<OpponentThreat> threats})
    : threats = List.unmodifiable(threats);

  final Chess position;
  final List<OpponentThreat> threats;

  factory ThreatResult.fromLines(Chess position, List<StockfishLine> lines) {
    final seen = <String>{};
    final threats = <OpponentThreat>[];
    for (final line in lines.take(3)) {
      final move = Move.parse(line.moves.first);
      if (move is! NormalMove || !seen.add(move.uci)) {
        throw StateError('Stockfish devolveu uma ameaça inválida.');
      }
      final (_, san) = position.makeSan(move);
      threats.add(OpponentThreat(san: san, move: move, line: line));
    }
    if (threats.isEmpty &&
        position.legalMoves.values.any((moves) => moves.isNotEmpty)) {
      throw StateError('Stockfish não devolveu variantes para esta posição.');
    }
    return ThreatResult(position: position, threats: threats);
  }
}
