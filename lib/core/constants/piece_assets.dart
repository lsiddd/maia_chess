import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// All twelve pieces: six roles in two colours.
final _allPieces = [
  for (final color in Side.values)
    for (final role in Role.values) Piece(color: color, role: role),
];

/// Decode and cache all twelve piece SVGs before the first board frame or
/// drag. The [context] must resolve the same `SvgTheme` and `AssetBundle` as
/// the board, since both contribute to the `flutter_svg` cache key.
Future<void> precachePieceSvgs(BuildContext context) {
  return Future.wait(
    _allPieces.map(
      (piece) => SvgAssetLoader(pieceAssetPath(piece)).loadBytes(context),
    ),
  );
}

/// Bundled SVG path for [piece]. Using assets avoids differences in Unicode
/// glyph shape and alignment between Android fonts.
String pieceAssetPath(Piece piece) {
  final role = switch (piece.role) {
    Role.king => 'K',
    Role.queen => 'Q',
    Role.rook => 'R',
    Role.bishop => 'B',
    Role.knight => 'N',
    Role.pawn => 'P',
  };
  final side = piece.color == Side.white ? 'w' : 'b';
  return 'assets/chess_pieces/$side$role.svg';
}

/// English role label used by promotion and accessibility announcements. The
/// legacy function name is retained for compatibility.
String roleLabelPt(Role role) {
  switch (role) {
    case Role.queen:
      return 'Queen';
    case Role.rook:
      return 'Rook';
    case Role.bishop:
      return 'Bishop';
    case Role.knight:
      return 'Knight';
    case Role.king:
      return 'King';
    case Role.pawn:
      return 'Pawn';
  }
}

String pieceLabelPt(Piece piece) {
  final color = piece.color == Side.white ? 'White' : 'Black';
  return '$color ${roleLabelPt(piece.role).toLowerCase()}';
}
