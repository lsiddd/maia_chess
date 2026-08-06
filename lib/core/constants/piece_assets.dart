import 'package:dartchess/dartchess.dart';

/// Caminho do SVG empacotado para [piece].
///
/// Usar assets próprios evita diferenças de desenho, alinhamento e peso dos
/// glifos Unicode entre versões do Android e fontes de fabricantes.
String pieceAssetPath(Piece piece) {
  final role = switch (piece.role) {
    Role.king => 'king',
    Role.queen => 'queen',
    Role.rook => 'rook',
    Role.bishop => 'bishop',
    Role.knight => 'knight',
    Role.pawn => 'pawn',
  };
  final side = piece.color == Side.white ? 'w' : 'b';
  return 'assets/chess_pieces/$role-$side.svg';
}

/// Nome em português do papel da peça — usado no diálogo de promoção.
String roleLabelPt(Role role) {
  switch (role) {
    case Role.queen:
      return 'Dama';
    case Role.rook:
      return 'Torre';
    case Role.bishop:
      return 'Bispo';
    case Role.knight:
      return 'Cavalo';
    case Role.king:
      return 'Rei';
    case Role.pawn:
      return 'Peão';
  }
}

String pieceLabelPt(Piece piece) {
  final color = piece.color == Side.white ? 'branco' : 'preto';
  return '${roleLabelPt(piece.role)} $color';
}
