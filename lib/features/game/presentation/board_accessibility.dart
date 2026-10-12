import 'package:dartchess/dartchess.dart';

import '../../../core/constants/piece_assets.dart';
import '../application/game_state.dart';
import '../../../data/repositories/game_repository.dart';

String boardSquareLabel(Square square, Piece? piece) =>
    '${square.name}, ${piece == null ? 'empty' : pieceLabelPt(piece)}';

/// Describe the last move for the status live region. Use the previous
/// position to identify a pawn that has just promoted.
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
        '${san.startsWith('O-O-O') ? 'queenside castling' : 'kingside castling'}';
  } else {
    description =
        '${pieceLabelPt(piece)} from ${move.from.name} to ${move.to.name}'
        '${san.contains('x') ? ', captures' : ''}'
        '${move.promotion == null ? '' : ', promotes to ${roleLabelPt(move.promotion!)}'}';
  }
  return '$description${san.endsWith('#') ? ', checkmate' : ''}.';
}

/// Persistent human-readable result and draw reason.
String gameResultDescription(GameState state) => switch (state.termination) {
  GameTermination.checkmate =>
    state.result == GameResult.vitoriaBrancas
        ? 'Checkmate! White wins.'
        : 'Checkmate! Black wins.',
  GameTermination.stalemate => 'Draw by stalemate.',
  GameTermination.insufficientMaterial => 'Draw by insufficient material.',
  GameTermination.threefoldRepetition => 'Draw by threefold repetition.',
  GameTermination.fiftyMoveRule => 'Draw by the fifty-move rule.',
  _ => state.isGameOver ? 'Game over: draw.' : '',
};
