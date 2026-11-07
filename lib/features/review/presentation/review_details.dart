import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theming/app_theme.dart';
import '../../history/domain/game_replayer.dart';
import '../domain/game_review.dart';

String sideLabel(Side side) => side == Side.white ? 'White' : 'Black';

String reviewMoveLabel(Chess before, String san) =>
    '${before.fullmoves}${before.turn == Side.white ? '.' : '...'} $san';

class ReviewEvaluationBar extends StatelessWidget {
  const ReviewEvaluationBar({super.key, required this.evaluation});

  final ReviewEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Stockfish evaluation from White’s perspective',
      value: evaluation.display,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: [
            Text(
              evaluation.display,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: evaluation.whiteWinPercent / 100,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  backgroundColor: const Color(0xFF262421),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewMoveDetails extends StatelessWidget {
  const ReviewMoveDetails({
    super.key,
    required this.move,
    required this.onBest,
    required this.onShow,
    required this.onRetry,
  });

  final ReviewedMove move;
  final VoidCallback? onBest;
  final VoidCallback? onShow;
  final VoidCallback? onRetry;

  String _explanation() {
    final reply = move.after.lines.firstOrNull?.sans.firstOrNull;
    final evaluation = move.playedEvaluation;
    final mate = evaluation.mate;
    if (evaluation.checkmatedSide != null) {
      return '${sideLabel(evaluation.checkmatedSide!.opposite)} delivered checkmate.';
    }
    if (mate != null) {
      final winner = mate.isNegative ? Side.black : Side.white;
      return 'Stockfish finds a forced mate for ${sideLabel(winner)} in ${mate.abs()}.';
    }
    if (move.quality == ReviewMoveQuality.best) {
      return 'This matches Stockfish’s top move.';
    }
    if (!move.quality.isMistake) {
      return 'This keeps most of ${sideLabel(move.side)}’s winning chances.';
    }
    final loss = move.winPercentLoss.toStringAsFixed(0);
    return reply == null
        ? 'This cost ${sideLabel(move.side)} $loss percentage points in estimated winning chances.'
        : '${sideLabel(move.side.opposite)} can reply with $reply. '
              '${sideLabel(move.side)} lost about $loss percentage points in estimated winning chances.';
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final best = move.before.lines.firstOrNull?.sans.firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sideLabel(move.side)} played ${move.san} · ${move.quality.label}',
              style: style.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(_explanation()),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Evaluation ${move.before.evaluation.display} → ${move.playedEvaluation.display}'
              '${best == null ? '' : '  ·  Best move $best'}',
              style: style.labelLarge,
            ),
            Wrap(
              children: [
                TextButton(onPressed: onBest, child: const Text('Best move')),
                TextButton(
                  onPressed: onShow,
                  child: const Text('Show continuation'),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry move'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewLines extends StatelessWidget {
  const ReviewLines({super.key, required this.lines, required this.onSelect});

  final List<ReviewLine> lines;
  final ValueChanged<ReviewLine> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.m,
              0,
            ),
            child: Text(
              'Engine lines',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final line in lines)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.xs,
              ),
              leading: Text(
                line.evaluation.display,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                line.sans.take(8).join(' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelect(line),
            ),
        ],
      ),
    );
  }
}

class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.review,
    required this.retrySide,
    required this.onRetrySide,
    required this.onLearn,
  });

  final GameReview review;
  final Side? retrySide;
  final ValueChanged<Side?> onRetrySide;
  final VoidCallback? onLearn;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final white = review.summary(Side.white);
    final black = review.summary(Side.black);
    String percent(double? value) =>
        value == null ? '–' : '${value.toStringAsFixed(1)}%';
    String number(double? value) => value?.toStringAsFixed(0) ?? '–';
    Widget row(String metric, String a, String b, {bool header = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(metric, style: header ? style.titleMedium : null),
              ),
              Expanded(child: Text(a, textAlign: TextAlign.center)),
              Expanded(child: Text(b, textAlign: TextAlign.center)),
            ],
          ),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game summary', style: style.titleLarge),
            const SizedBox(height: AppSpacing.m),
            row('Move quality', 'White', 'Black', header: true),
            row('Accuracy', percent(white.accuracy), percent(black.accuracy)),
            row(
              'Avg. centipawn loss',
              number(white.averageCentipawnLoss),
              number(black.averageCentipawnLoss),
            ),
            const Divider(),
            for (final quality in ReviewMoveQuality.values)
              row(
                quality.label,
                white.counts[quality].toString(),
                black.counts[quality].toString(),
              ),
            if (review.keyMoments.isNotEmpty) ...[
              const Divider(),
              Text('Practice mistakes by side', style: style.titleSmall),
              const SizedBox(height: AppSpacing.s),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final side in <Side?>[null, Side.white, Side.black])
                    ChoiceChip(
                      label: Text(side == null ? 'Both' : sideLabel(side)),
                      selected: side == retrySide,
                      onSelected: (_) => onRetrySide(side),
                    ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: onLearn,
                icon: const Icon(Icons.psychology_outlined),
                label: const Text('Learn from mistakes'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReviewMoveList extends StatelessWidget {
  const ReviewMoveList({
    super.key,
    required this.replayed,
    required this.review,
    required this.ply,
    required this.onSelect,
  });

  static const _pageSize = 24;

  final ReplayedGame replayed;
  final GameReview? review;
  final int ply;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final count = replayed.sans.length;
    final first = ((ply - 1).clamp(0, count) ~/ _pageSize) * _pageSize;
    final end = (first + _pageSize).clamp(0, count);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move list', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (first == 0)
                  ChoiceChip(
                    label: const Text('Start'),
                    selected: ply == 0,
                    onSelected: (_) => onSelect(0),
                  ),
                for (var i = first; i < end; i++) _moveChip(i),
              ],
            ),
            if (count > _pageSize)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous moves',
                    onPressed: first == 0 ? null : () => onSelect(first),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Half-moves ${first + 1}–$end of $count'),
                  IconButton(
                    tooltip: 'More moves',
                    onPressed: end == count ? null : () => onSelect(end + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _moveChip(int i) {
    final label = reviewMoveLabel(replayed.positions[i], replayed.sans[i]);
    final quality = review?.moves[i].quality;
    final annotation = switch (quality) {
      ReviewMoveQuality.best => '!',
      ReviewMoveQuality.inaccuracy => '?!',
      ReviewMoveQuality.mistake || ReviewMoveQuality.missed => '?',
      ReviewMoveQuality.blunder => '??',
      _ => '',
    };
    return Tooltip(
      message: quality == null ? label : '$label, ${quality.label}',
      child: ChoiceChip(
        label: Text('$label$annotation'),
        selected: ply == i + 1,
        onSelected: (_) => onSelect(i + 1),
      ),
    );
  }
}

class ReviewVariationList extends StatelessWidget {
  const ReviewVariationList({
    super.key,
    required this.positions,
    required this.sans,
    required this.step,
    required this.onSelect,
  });

  final List<Chess> positions;
  final List<String> sans;
  final int step;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Variation', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Start'),
                  selected: step == 0,
                  onSelected: (_) => onSelect(0),
                ),
                for (final (index, san) in sans.indexed)
                  ChoiceChip(
                    label: Text(reviewMoveLabel(positions[index], san)),
                    selected: step == index + 1,
                    onSelected: (_) => onSelect(index + 1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
