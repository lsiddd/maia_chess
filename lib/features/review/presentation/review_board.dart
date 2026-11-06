import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../game/application/chess_move_rules.dart';
import '../../game/presentation/chess_board_widget.dart';
import '../../game/presentation/promotion_dialog.dart';

class ReviewBoard extends StatefulWidget {
  const ReviewBoard({
    super.key,
    required this.position,
    required this.orientation,
    required this.onMove,
    this.lastMove,
    this.suggestion,
    this.enabled = true,
  });

  final Chess position;
  final Side orientation;
  final ValueChanged<String> onMove;
  final NormalMove? lastMove;
  final NormalMove? suggestion;
  final bool enabled;

  @override
  State<ReviewBoard> createState() => _ReviewBoardState();
}

class _ReviewBoardState extends State<ReviewBoard> {
  Square? _selected;
  bool _promoting = false;

  @override
  void didUpdateWidget(covariant ReviewBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position.fen != widget.position.fen ||
        oldWidget.orientation != widget.orientation ||
        !widget.enabled) {
      _selected = null;
    }
  }

  Future<void> _tapSquare(Square square) async {
    if (_promoting) return;
    final position = widget.position;
    final from = _selected;
    if (from != null &&
        legalChessDestinations(position, from).contains(square)) {
      var move = NormalMove(from: from, to: square);
      if (position.board.pieceAt(from)?.role == Role.pawn &&
          SquareSet.backranks.has(square)) {
        _promoting = true;
        final promotion = await showPromotionDialog(context, position.turn);
        if (!mounted) return;
        _promoting = false;
        if (promotion == null ||
            position.fen != widget.position.fen ||
            !widget.enabled) {
          return;
        }
        move = move.withPromotion(promotion);
      }
      if (position.isLegal(move)) {
        setState(() => _selected = null);
        widget.onMove(move.uci);
      }
    } else {
      setState(() {
        _selected =
            from != square &&
                position.board.pieceAt(square)?.color == position.turn
            ? square
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final suggestion = widget.suggestion;
    return StaticChessBoardWidget(
      position: widget.position,
      orientation: widget.orientation,
      selectedSquare: selected,
      legalTargets: selected == null
          ? const {}
          : legalChessDestinations(widget.position, selected),
      lastMove: widget.lastMove,
      onSquareTap: widget.enabled ? _tapSquare : null,
      overlay: suggestion == null
          ? null
          : CustomPaint(
              painter: _SuggestionPainter(
                suggestion,
                widget.orientation,
                Theme.of(context).colorScheme.primary,
              ),
            ),
    );
  }
}

/// Show king destinations for castling regardless of the engine's UCI encoding.
NormalMove? reviewBoardMove(Chess position, String? uci) {
  if (uci == null) return null;
  final move = Move.parse(uci);
  if (move is! NormalMove) return null;
  final piece = position.board.pieceAt(move.from);
  if (piece?.role == Role.king &&
      position.board.pieceAt(move.to) ==
          Piece(color: piece!.color, role: Role.rook)) {
    final side = move.to > move.from ? CastlingSide.king : CastlingSide.queen;
    return NormalMove(from: move.from, to: kingCastlesTo(piece.color, side));
  }
  return move;
}

class _SuggestionPainter extends CustomPainter {
  const _SuggestionPainter(this.move, this.orientation, this.color);

  final NormalMove move;
  final Side orientation;
  final Color color;

  Offset _center(Square square, double cell) {
    final file = square.file.value;
    final rank = square.rank.value;
    return orientation == Side.white
        ? Offset((file + .5) * cell, (7.5 - rank) * cell)
        : Offset((7.5 - file) * cell, (rank + .5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    final from = _center(move.from, cell);
    final to = _center(move.to, cell);
    final distance = (to - from).distance;
    if (distance == 0) return;
    final direction = (to - from) / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final base = to - direction * cell * .26;
    final arrow = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo((base + normal * cell * .16).dx, (base + normal * cell * .16).dy)
      ..lineTo((base - normal * cell * .16).dx, (base - normal * cell * .16).dy)
      ..close();
    final outline = Paint()
      ..color = Colors.black54
      ..strokeWidth = cell * .14
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..strokeWidth = cell * .09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, base, outline);
    canvas.drawLine(from, base, fill);
    canvas.drawPath(arrow, fill);
  }

  @override
  bool shouldRepaint(_SuggestionPainter oldDelegate) =>
      move != oldDelegate.move ||
      orientation != oldDelegate.orientation ||
      color != oldDelegate.color;
}
