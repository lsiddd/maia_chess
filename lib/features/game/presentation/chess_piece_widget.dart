import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/piece_assets.dart';

/// Vector piece with consistent artwork across platforms. Its parent square
/// determines size; the SVG does not affect board geometry.
class ChessPieceWidget extends StatelessWidget {
  const ChessPieceWidget({required this.piece, super.key});

  final Piece piece;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: pieceLabelPt(piece),
      child: RepaintBoundary(
        child: SvgPicture.asset(
          pieceAssetPath(piece),
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
