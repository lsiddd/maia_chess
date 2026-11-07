import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theming/app_theme.dart';

class ReviewChart extends StatelessWidget {
  const ReviewChart({
    super.key,
    required this.whiteWinPercent,
    required this.ply,
    required this.onSelect,
  });

  final List<double> whiteWinPercent;
  final int ply;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (whiteWinPercent.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game balance', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'White above the line · Black below',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.m),
            LayoutBuilder(
              builder: (context, constraints) {
                final last = whiteWinPercent.length - 1;
                void select(double x) {
                  if (constraints.maxWidth <= 0) return;
                  onSelect(
                    (x / constraints.maxWidth * last).round().clamp(0, last),
                  );
                }

                return Semantics(
                  label:
                      'Evaluation graph, white advantage above the centre line',
                  value: 'Position $ply of $last',
                  increasedValue: ply < last
                      ? 'Position ${ply + 1} of $last'
                      : null,
                  decreasedValue: ply > 0
                      ? 'Position ${ply - 1} of $last'
                      : null,
                  onIncrease: ply < last ? () => onSelect(ply + 1) : null,
                  onDecrease: ply > 0 ? () => onSelect(ply - 1) : null,
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (event) => select(event.localPosition.dx),
                    onHorizontalDragStart: (event) =>
                        select(event.localPosition.dx),
                    onHorizontalDragUpdate: (event) =>
                        select(event.localPosition.dx),
                    child: SizedBox(
                      height: 76,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _ChartPainter(whiteWinPercent, ply, colors),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter(this.scores, this.ply, this.colors);

  final List<double> scores;
  final int ply;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final step = size.width / (scores.length - 1).clamp(1, scores.length);
    Offset point(int index) =>
        Offset(index * step, (1 - scores[index] / 100) * size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainer,
    );
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()..color = colors.outlineVariant,
    );
    final curve = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < scores.length; i++) {
      final next = point(i);
      curve.lineTo(next.dx, next.dy);
    }
    final fill = Path.from(curve)
      ..lineTo(size.width, mid)
      ..lineTo(0, mid)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = colors.primary.withValues(alpha: .23),
    );
    canvas.drawPath(
      curve,
      Paint()
        ..color = colors.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final selected = point(ply.clamp(0, scores.length - 1));
    canvas.drawLine(
      Offset(selected.dx, 0),
      Offset(selected.dx, size.height),
      Paint()..color = colors.onSurfaceVariant,
    );
    canvas.drawCircle(selected, 3, Paint()..color = colors.onSurface);
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      ply != oldDelegate.ply ||
      colors != oldDelegate.colors ||
      !listEquals(scores, oldDelegate.scores);
}
