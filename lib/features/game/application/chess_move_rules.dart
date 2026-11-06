import 'package:dartchess/dartchess.dart';

/// Legal destinations from [square], or none if it has no piece for the
/// side to move.
Set<Square> legalChessDestinations(Chess position, Square square) {
  final destinations = position.legalMovesOf(square).squares.toSet();

  // dartchess represents castling as king-to-rook for Chess960
  // compatibility. This app uses standard chess destinations g/c, with
  // final validation through `makeSan`.
  final piece = position.board.pieceAt(square);
  if (piece?.role == Role.king) {
    final rank = piece!.color == Side.white ? Rank.first : Rank.eighth;
    final kingSideRook = Square.fromCoords(File.h, rank);
    final queenSideRook = Square.fromCoords(File.a, rank);
    // A corner can also be a normal king move, check escape, or capture.
    // Convert king-to-rook only if the square actually holds a friendly
    // rook.
    final ownRook = Piece(color: piece.color, role: Role.rook);
    if (position.board.pieceAt(kingSideRook) == ownRook &&
        destinations.remove(kingSideRook)) {
      destinations.add(Square.fromCoords(File.g, rank));
    }
    if (position.board.pieceAt(queenSideRook) == ownRook &&
        destinations.remove(queenSideRook)) {
      destinations.add(Square.fromCoords(File.c, rank));
    }
  }
  return destinations;
}
