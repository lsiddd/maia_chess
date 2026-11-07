import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/difficulty_levels.dart';
import '../../../core/theming/app_theme.dart';
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
      appBar: AppBar(title: const Text('My performance')),
      body: SafeArea(
        top: false,
        child: MaxWidthBody(
          child: stats.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading performance',
              ),
            ),
            error: (error, stackTrace) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: ErrorStateCard(
                  message:
                      'Your performance could not be loaded. Please try again.',
                  onRetry: () => ref.invalidate(playerStatsProvider),
                ),
              ),
            ),
            data: (snapshot) => _StatsBody(stats: snapshot),
          ),
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
    final theme = Theme.of(context);
    final playedLevels = DifficultyLevel.all
        .where((level) => (stats.resultsByLevel[level.rating]?.total ?? 0) > 0)
        .toList(growable: false);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Every game tells a story.',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Track your progress against Maia.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _RatingHero(stats: stats),
                const SizedBox(height: AppSpacing.m),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(16) > 22;
                    final current = _MetricCard(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Current streak',
                      value: '${stats.currentStreak}',
                      suffix: _plural(stats.currentStreak, 'win', 'wins'),
                    );
                    final best = _MetricCard(
                      icon: Icons.emoji_events_outlined,
                      label: 'Best streak',
                      value: '${stats.recordStreak}',
                      suffix: _plural(stats.recordStreak, 'win', 'wins'),
                    );
                    return stacked
                        ? Column(
                            children: [
                              current,
                              const SizedBox(height: AppSpacing.m),
                              best,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: current),
                              const SizedBox(width: AppSpacing.m),
                              Expanded(child: best),
                            ],
                          );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    'Results by level',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Wins, draws and losses in rated games.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (stats.evaluatedGames == 0)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.xxl,
            ),
            sliver: SliverToBoxAdapter(
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Your results will appear here after your first rated game. Local games and imported games do not affect your rating.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.xxl,
            ),
            sliver: SliverList.separated(
              itemCount: playedLevels.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (context, index) {
                final level = playedLevels[index];
                return _LevelScoreCard(
                  rating: level.rating,
                  results:
                      stats.resultsByLevel[level.rating] ??
                      const LevelResults(),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESTIMATED RATING',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.s,
              children: [
                Text(
                  stats.evaluatedGames == 0
                      ? '—'
                      : '${stats.estimatedRating.round()}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontFamily: AppTypography.accentFontFamily,
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  '${stats.evaluatedGames} rated ${_plural(stats.evaluatedGames, 'game', 'games')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (stats.ratingHistory.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.l),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.trending_up, color: colors.primary, size: 28),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      'Your progress starts here.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    const Text(
                      'Complete a rated game against Maia-3 to start your rating history.',
                    ),
                  ],
                ),
              )
            else ...[
              Semantics(
                label:
                    'Rating chart with ${stats.ratingHistory.length} ${_plural(stats.ratingHistory.length, 'point', 'points')}; current rating ${stats.estimatedRating.round()}',
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _RatingChartPainter(
                      points: stats.ratingHistory,
                      lineColor: colors.primary,
                      gridColor: colors.outlineVariant,
                      labelColor: colors.onSurfaceVariant,
                      fillColor: colors.primary.withValues(alpha: 0.1),
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'First game',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Flexible(
                    child: Text(
                      'Latest game',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: AppTypography.accentFontFamily,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: ' $suffix'),
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
    return Semantics(
      label:
          'Maia $rating. ${results.total} ${_plural(results.total, 'game', 'games')}: ${results.wins} ${_plural(results.wins, 'win', 'wins')}, ${results.draws} ${_plural(results.draws, 'draw', 'draws')}, ${results.losses} ${_plural(results.losses, 'loss', 'losses')}.',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.l,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Maia $rating', style: theme.textTheme.titleMedium),
                  Text(
                    '${results.total} ${_plural(results.total, 'game', 'games')}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      if (results.wins > 0)
                        Expanded(
                          flex: results.wins,
                          child: ColoredBox(color: colors.primary),
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
                          child: ColoredBox(
                            color: colors.surfaceContainerHighest,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                '${results.wins}W  ${results.draws}D  ${results.losses}L',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
    required this.textScaler,
  });

  final List<RatingPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color fillColor;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final left = textScaler.scale(12) * 3.3;
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
          style: TextStyle(color: labelColor, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      text.paint(
        canvas,
        Offset(chart.left - text.width - 6, y - text.height / 2),
      );
      text.dispose();
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
    return oldDelegate.textScaler != textScaler ||
        oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.fillColor != fillColor;
  }
}

String _plural(int count, String singular, String plural) =>
    count == 1 ? singular : plural;
