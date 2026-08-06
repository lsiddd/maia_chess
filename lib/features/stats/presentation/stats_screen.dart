import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/difficulty_levels.dart';
import '../../../core/widgets/error_state_card.dart';
import '../../../core/widgets/max_width_body.dart';
import '../../../data/providers.dart';
import '../domain/player_stats.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playerStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meu desempenho')),
      body: MaxWidthBody(
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorStateCard(
                message: 'Não foi possível calcular as estatísticas: $error',
                onRetry: () => ref.invalidate(playerStatsProvider),
              ),
            ),
          ),
          data: (snapshot) => _StatsBody(stats: snapshot),
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final PlayerStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          sliver: SliverToBoxAdapter(child: _RatingHero(stats: stats)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Sequência atual',
                    value: '${stats.currentStreak}',
                    suffix: 'vitórias',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.emoji_events_outlined,
                    label: 'Recorde',
                    value: '${stats.recordStreak}',
                    suffix: 'vitórias',
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Placar por nível',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverList.separated(
            itemCount: DifficultyLevel.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final level = DifficultyLevel.all[index];
              return _LevelScoreCard(
                rating: level.rating,
                results:
                    stats.resultsByLevel[level.rating] ?? const LevelResults(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RatingHero extends StatelessWidget {
  const _RatingHero({required this.stats});

  final PlayerStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RATING ESTIMADO',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.5,
              color: colors.onPrimaryContainer.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.estimatedRating.round()}',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  '${stats.evaluatedGames} partidas avaliadas',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (stats.ratingHistory.isEmpty)
            Container(
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Termine uma partida avaliada contra o Maia para iniciar '
                  'sua linha de evolução.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Semantics(
              label:
                  'Gráfico de evolução com ${stats.ratingHistory.length} '
                  'pontos; rating atual ${stats.estimatedRating.round()}',
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RatingChartPainter(
                    points: stats.ratingHistory,
                    lineColor: colors.primary,
                    gridColor: colors.onSurface.withValues(alpha: 0.12),
                    labelColor: colors.onSurfaceVariant,
                    fillColor: colors.primary.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  final IconData icon;
  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.tertiary),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: '  $suffix'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelScoreCard extends StatelessWidget {
  const _LevelScoreCard({required this.rating, required this.results});

  final int rating;
  final LevelResults results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = math.max(1, results.total);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '$rating',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${results.total} partidas',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        '${results.wins}V  ${results.draws}E  '
                        '${results.losses}D',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          if (results.wins > 0)
                            Expanded(
                              flex: results.wins,
                              child: ColoredBox(color: colors.tertiary),
                            ),
                          if (results.draws > 0)
                            Expanded(
                              flex: results.draws,
                              child: ColoredBox(color: colors.secondary),
                            ),
                          if (results.losses > 0)
                            Expanded(
                              flex: results.losses,
                              child: ColoredBox(color: colors.error),
                            ),
                          if (results.total == 0)
                            Expanded(
                              flex: total,
                              child: ColoredBox(
                                color: colors.surfaceContainerHighest,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChartPainter extends CustomPainter {
  _RatingChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.fillColor,
  });

  final List<RatingPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const top = 10.0;
    const bottom = 24.0;
    const right = 8.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final values = points.map((point) => point.value);
    var low = values.reduce(math.min);
    var high = values.reduce(math.max);
    if ((high - low).abs() < 40) {
      final center = (high + low) / 2;
      low = center - 20;
      high = center + 20;
    } else {
      final padding = (high - low) * 0.12;
      low -= padding;
      high += padding;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = chart.top + chart.height * index / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = (high - (high - low) * index / 2).round().toString();
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(chart.left - text.width - 6, y - text.height / 2),
      );
    }

    Offset coordinate(int index, double value) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final y = chart.bottom - chart.height * (value - low) / (high - low);
      return Offset(x, y);
    }

    final line = Path();
    for (var index = 0; index < points.length; index++) {
      final point = coordinate(index, points[index].value);
      if (index == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    final fill = Path.from(line)
      ..lineTo(
        coordinate(points.length - 1, points.last.value).dx,
        chart.bottom,
      )
      ..lineTo(coordinate(0, points.first.value).dx, chart.bottom)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (var index = 0; index < points.length; index++) {
      final point = coordinate(index, points[index].value);
      canvas.drawCircle(point, 4.5, Paint()..color = lineColor);
      canvas.drawCircle(
        point,
        2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RatingChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
