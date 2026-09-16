import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Todas as 12 peças possíveis (6 papéis × 2 cores).
final _allPieces = [
  for (final color in Side.values)
    for (final role in Role.values) Piece(color: color, role: role),
];

/// Decodifica e guarda em cache os SVGs das 12 peças.
///
/// Sem isto, cada peça só é lida e parseada na primeira vez que aparece na
/// tela — o que cai justamente no primeiro quadro do tabuleiro e no
/// primeiro arraste/animação, causando engasgo visível. O [context] precisa
/// ser o mesmo tipo de contexto em que as peças serão desenhadas: a chave de
/// cache do `flutter_svg` inclui o `SvgTheme` e o `AssetBundle` resolvidos a
/// partir dele.
Future<void> precachePieceSvgs(BuildContext context) {
  return Future.wait(
    _allPieces.map(
      (piece) => SvgAssetLoader(pieceAssetPath(piece)).loadBytes(context),
    ),
  );
}

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
