import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/tactical_analysis.dart';

const threatArrowColors = [
  Color(0xFFE53935),
  Color(0xFFFFA000),
  Color(0xFF00897B),
];

/// Arrow layer independent of gestures and piece animation. Numbering makes
/// rank readable without relying on colour.
class ThreatArrows extends StatelessWidget {
  const ThreatArrows({
    super.key,
    required this.threats,
    required this.orientation,
  });

  final List<OpponentThreat> threats;
  final Side orientation;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const Key('opponent-threat-arrows'),
        painter: ThreatArrowPainter(threats: threats, orientation: orientation),
      ),
    ),
  );
}

class ThreatArrowPainter extends CustomPainter {
  const ThreatArrowPainter({required this.threats, required this.orientation});

  final List<OpponentThreat> threats;
  final Side orientation;

  Offset squareCenter(Square square, Size size) {
    final white = orientation == Side.white;
    return Offset(
      ((white ? square.file.value : 7 - square.file.value) + 0.5) *
          size.width /
          8,
      ((white ? 7 - square.rank.value : square.rank.value) + 0.5) *
          size.height /
          8,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width, size.height) / 8;
    // Draw the highest-ranked candidate last so it remains visible in
    // overlaps.
    for (var i = threats.length - 1; i >= 0; i--) {
      final threat = threats[i];
      final from = squareCenter(threat.move.from, size);
      final to = squareCenter(threat.move.to, size);
      final vector = to - from;
      final length = vector.distance;
      if (length == 0) continue;
      final direction = vector / length;
      final normal = Offset(-direction.dy, direction.dx);
      final tip = to - direction * cell * 0.12;
      final base = tip - direction * cell * 0.28;
      final shaft = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(base.dx, base.dy);
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (base + normal * cell * 0.18).dx,
          (base + normal * cell * 0.18).dy,
        )
        ..lineTo(
          (base - normal * cell * 0.18).dx,
          (base - normal * cell * 0.18).dy,
        )
        ..close();
      final color = threatArrowColors[i % threatArrowColors.length];
      canvas.drawPath(
        shaft,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = cell * 0.14,
      );
      canvas.drawPath(
        shaft,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = cell * 0.10,
      );
      canvas.drawPath(head, Paint()..color = color.withValues(alpha: 0.9));
      canvas.drawPath(
        head,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.02,
      );
      // Badges distinguish promotions sharing origin/destination and
      // candidates moving the same piece.
      final badge = from + direction * length * (0.25 + i * 0.18);
      canvas.drawCircle(badge, cell * 0.16, Paint()..color = color);
      canvas.drawCircle(
        badge,
        cell * 0.16,
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.025,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.black,
            fontSize: cell * 0.24,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, badge - Offset(label.width / 2, label.height / 2));
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(ThreatArrowPainter oldDelegate) =>
      orientation != oldDelegate.orientation ||
      !listEquals(threats, oldDelegate.threats);
}
