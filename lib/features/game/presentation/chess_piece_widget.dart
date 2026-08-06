import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/piece_assets.dart';

/// Peça vetorial consistente em todas as plataformas.
///
/// O tamanho é sempre imposto pela casa que hospeda este widget; o SVG nunca
/// participa do cálculo da geometria do tabuleiro.
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
