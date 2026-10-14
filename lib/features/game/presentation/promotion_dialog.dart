import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/piece_assets.dart';
import 'chess_piece_widget.dart';

const _promotionChoices = [Role.queen, Role.rook, Role.bishop, Role.knight];

/// Choose a promotion role, returning null when the player cancels, including
/// by tapping outside.
Future<Role?> showPromotionDialog(
  BuildContext context,
  Side side, {
  void Function(DialogRoute<Role>)? onRoute,
}) {
  final route = DialogRoute<Role>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Promote pawn to'),
      content: Wrap(
        alignment: WrapAlignment.center,
        children: _promotionChoices.map((role) {
          final piece = Piece(color: side, role: role);
          return IconButton(
            iconSize: 48,
            tooltip: roleLabelPt(role),
            onPressed: () => Navigator.of(context).pop(role),
            icon: SizedBox.square(
              dimension: 48,
              child: ChessPieceWidget(piece: piece),
            ),
          );
        }).toList(),
      ),
    ),
  );
  onRoute?.call(route);
  return Navigator.of(context, rootNavigator: true).push(route);
}
