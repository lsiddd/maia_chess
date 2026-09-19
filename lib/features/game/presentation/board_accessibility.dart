import 'package:dartchess/dartchess.dart';

import '../../../core/constants/piece_assets.dart';
import '../application/game_state.dart';

String boardSquareLabel(Square square, Piece? piece) =>
    '${square.name}, ${piece == null ? 'vazia' : pieceLabelPt(piece)}';

/// Descreve o último lance por extenso para a região viva da barra de estado.
/// Usa a posição anterior para identificar também o peão que promoveu.
String lastMoveAnnouncement(GameState state) {
  if (state.uciHistory.isEmpty || state.positionHistory.isEmpty) return '';
  final move = Move.parse(state.uciHistory.last);
  if (move is! NormalMove) return '';
  final piece = state.positionHistory.last.board.pieceAt(move.from);
  if (piece == null) return '';
  final san = state.sanHistory.last;
  final String description;
  if (san.startsWith('O-O')) {
    description =
        '${pieceLabelPt(piece)}, '
        '${san.startsWith('O-O-O') ? 'roque grande' : 'roque pequeno'}';
  } else {
    description =
        '${pieceLabelPt(piece)} de ${move.from.name} para ${move.to.name}'
        '${san.contains('x') ? ', captura' : ''}'
        '${move.promotion == null ? '' : ', promove a ${roleLabelPt(move.promotion!)}'}';
  }
  return '$description${san.endsWith('#') ? ', xeque-mate' : ''}.';
}
