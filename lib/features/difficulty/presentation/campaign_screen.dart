import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_page_route.dart';
import '../../../core/theming/app_theme.dart';
import '../../../core/widgets/error_state_card.dart';
import '../../../core/widgets/max_width_body.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../game/application/game_controller.dart';
import '../../game/presentation/game_screen.dart';
import '../../game/presentation/time_control_picker.dart';
import '../../game/application/time_control.dart';

class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({super.key});

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  Side _humanSide = Side.white;
  TimeControl _timeControl = const TimeControl();
  int? _startingRating;
  bool _leaving = false;
  GameStartRequest? _startRequest;
  Future<bool>? _pendingStart;

  @override
  void dispose() {
    _startRequest?.cancel();
    super.dispose();
  }

  Future<void> _leaveWhileStarting() async {
    if (_leaving || !mounted) return;
    final route = ModalRoute.of(context);
    _leaving = true;
    _startRequest?.cancel();
    await _pendingStart?.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    if (mounted) {
      setState(() => _startingRating = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _startLevel(DifficultyProgressModel progress) async {
    if (!_timeControl.isValid ||
        !progress.unlocked ||
        _startingRating != null ||
        _leaving) {
      return;
    }
    setState(() => _startingRating = progress.rating);
    final request = _startRequest = GameStartRequest();
    try {
      final active = await ref.read(gameRepositoryProvider).getActiveGame();
      if (!mounted || request.isCancelled) return;
      if (active != null) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace the ongoing game?'),
            content: const Text(
              'The current autosave will be removed when the campaign '
              'level begins.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Start campaign'),
              ),
            ],
          ),
        );
        if (replace != true || !mounted || request.isCancelled) return;
      }
      final pending = _pendingStart = ref
          .read(gameControllerProvider.notifier)
          .startVsAi(
            humanSide: _humanSide,
            levelRating: progress.rating,
            campaignMode: true,
            timeControl: _timeControl,
            request: request,
          );
      final started = await pending;
      if (!mounted || request.isCancelled || _leaving) return;
      _startRequest = null;
      if (!started) {
        final state = ref.read(gameControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.engineError ??
                  state.persistenceError ??
                  'Could not start this level.',
            ),
          ),
        );
        return;
      }
      await Navigator.of(
        context,
      ).push(AppPageRoute(builder: (_) => const GameScreen()));
    } catch (error) {
      if (!mounted || request.isCancelled || _leaving) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start this level: $error')),
      );
    } finally {
      _pendingStart = null;
      _startRequest = null;
      if (mounted) setState(() => _startingRating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(difficultyProgressProvider);
    final scaffold = Scaffold(
      appBar: AppBar(title: const Text('Maia-3 campaign')),
      body: MaxWidthBody(
        child: progress.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(semanticsLabel: 'Opening campaign'),
                SizedBox(height: AppSpacing.l),
                Text('Opening your campaign…'),
              ],
            ),
          ),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorStateCard(
                message: 'Could not open the campaign: $error',
                onRetry: () => ref.invalidate(difficultyProgressProvider),
              ),
            ),
          ),
          data: (levels) {
            if (levels.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ErrorStateCard(
                    message: 'No campaign levels are available yet.',
                    onRetry: () => ref.invalidate(difficultyProgressProvider),
                  ),
                ),
              );
            }
            final nextLevels = levels.where(
              (level) => level.unlocked && !level.levelCompleted,
            );
            final nextLevel = nextLevels.isEmpty ? null : nextLevels.first;
            final remainingLevels = levels
                .where((level) => level != nextLevel)
                .toList();
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.l,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _CampaignHeader(
                      completed: levels
                          .where((level) => level.levelCompleted)
                          .length,
                      total: levels.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        title: const Text('Game setup'),
                        expansionAnimationStyle: AnimationStyle(
                          duration: AppMotion.duration(
                            context,
                            AppMotion.medium,
                          ),
                          curve: AppMotion.curve,
                        ),
                        subtitle: Text(
                          '${_humanSide == Side.white ? 'White' : 'Black'} · '
                          '${timeControlLabel(_timeControl)}',
                        ),
                        leading: const Icon(Icons.tune),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.l,
                          0,
                          AppSpacing.l,
                          AppSpacing.l,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Play as',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<Side>(
                              direction:
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      20
                                  ? Axis.vertical
                                  : Axis.horizontal,
                              segments: const [
                                ButtonSegment(
                                  value: Side.white,
                                  icon: Icon(Icons.circle_outlined),
                                  label: Text('White'),
                                ),
                                ButtonSegment(
                                  value: Side.black,
                                  icon: Icon(Icons.circle),
                                  label: Text('Black'),
                                ),
                              ],
                              selected: {_humanSide},
                              onSelectionChanged: _startingRating != null
                                  ? null
                                  : (selection) => setState(
                                      () => _humanSide = selection.first,
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.l),
                          TimeControlPicker(
                            framed: false,
                            value: _timeControl,
                            onChanged: _startingRating != null
                                ? null
                                : (value) =>
                                      setState(() => _timeControl = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (nextLevel != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your next challenge',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          _CampaignLevelCard(
                            progress: nextLevel,
                            finalLevel: nextLevel == levels.last,
                            busy:
                                _startingRating != null ||
                                !_timeControl.isValid,
                            starting: _startingRating == nextLevel.rating,
                            onPlay: () => _startLevel(nextLevel),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (remainingLevels.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.m,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Your path',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: remainingLevels.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s),
                      itemBuilder: (context, index) {
                        final levelProgress = remainingLevels[index];
                        return _CampaignLevelCard(
                          progress: levelProgress,
                          finalLevel: levelProgress == levels.last,
                          busy:
                              _startingRating != null || !_timeControl.isValid,
                          starting: _startingRating == levelProgress.rating,
                          onPlay: () => _startLevel(levelProgress),
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
    return PopScope<void>(
      canPop: _startingRating == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _leaving = true;
          _startRequest?.cancel();
        } else {
          unawaited(_leaveWhileStarting());
        }
      },
      child: scaffold,
    );
  }
}

class _CampaignHeader extends StatelessWidget {
  const _CampaignHeader({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          completed == total
              ? 'Every level. Well played.'
              : 'One level at a time.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          'Climb through all 16 Maia-3 levels',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        LinearProgressIndicator(
          value: completed / total,
          minHeight: 6,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          semanticsLabel:
              'Campaign progress: $completed of $total levels completed',
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          '$completed of $total levels completed',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.l),
        Text(
          'Win 2 of your last 3 rated games to unlock the next level. '
          'Campaign games are played without assistance.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CampaignLevelCard extends StatelessWidget {
  const _CampaignLevelCard({
    required this.progress,
    required this.finalLevel,
    required this.busy,
    required this.starting,
    required this.onPlay,
  });

  final DifficultyProgressModel progress;
  final bool finalLevel;
  final bool busy;
  final bool starting;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final completed = progress.levelCompleted;
    final active = progress.unlocked && !completed;
    final status = !progress.unlocked
        ? 'Locked'
        : completed
        ? finalLevel
              ? 'Campaign completed'
              : 'Level completed'
        : '${progress.validWins}/${progress.winsRequired} wins • '
              '${progress.gamesInWindow}/${progress.windowSize} games';

    return Card(
      margin: EdgeInsets.zero,
      color: active ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: active ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: active ? colors.primary : colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(
                      completed
                          ? Icons.check
                          : progress.unlocked
                          ? Icons.flag_outlined
                          : Icons.lock_outline,
                      color: active
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maia-3 ${progress.rating}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: AppTypography.accentFontFamily,
                          color: active
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        status,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: active
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: AppSpacing.l),
              LinearProgressIndicator(
                value: (progress.validWins / progress.winsRequired).clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                semanticsLabel:
                    'Wins toward next level: '
                    '${progress.validWins} of ${progress.winsRequired} wins',
              ),
            ],
            if (progress.unlocked) ...[
              const SizedBox(height: AppSpacing.l),
              FilledButton.icon(
                onPressed: busy ? null : onPlay,
                icon: starting
                    ? const SizedBox.square(
                        key: ValueKey('level-starting-spinner'),
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(completed ? Icons.replay : Icons.arrow_forward),
                label: Text(
                  starting
                      ? 'Preparing game…'
                      : completed
                      ? 'Play again'
                      : 'Play level',
                ),
              ),
              if (starting) ...[
                const SizedBox(height: AppSpacing.s),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'The first game may take a few seconds to prepare.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: active
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
