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

class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({super.key});

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  Side _humanSide = Side.white;
  int? _startingRating;

  Future<void> _startLevel(DifficultyProgressModel progress) async {
    if (!progress.unlocked || _startingRating != null) return;
    final active = await ref.read(gameRepositoryProvider).getActiveGame();
    if (!mounted) return;
    if (active != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Substituir partida em andamento?'),
          content: const Text(
            'A partida atual será removida do autosave quando a etapa da '
            'campanha começar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Começar campanha'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    setState(() => _startingRating = progress.rating);
    try {
      final started = await ref
          .read(gameControllerProvider.notifier)
          .startVsAi(
            humanSide: _humanSide,
            levelRating: progress.rating,
            campaignMode: true,
          );
      if (!mounted) return;
      if (!started) {
        final state = ref.read(gameControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.engineError ??
                  state.persistenceError ??
                  'Não foi possível iniciar esta etapa.',
            ),
          ),
        );
        return;
      }
      await Navigator.of(
        context,
      ).push(AppPageRoute(builder: (_) => const GameScreen()));
    } finally {
      if (mounted) setState(() => _startingRating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(difficultyProgressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Campanha Maia')),
      body: MaxWidthBody(
        child: progress.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorStateCard(
                message: 'Não foi possível abrir a campanha: $error',
                onRetry: () => ref.invalidate(difficultyProgressProvider),
              ),
            ),
          ),
          data: (levels) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _CampaignHeader(
                    humanSide: _humanSide,
                    onSideChanged: _startingRating == null
                        ? (side) => setState(() => _humanSide = side)
                        : null,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList.separated(
                  itemCount: levels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = levels[index];
                    return _CampaignLevelCard(
                      progress: item,
                      finalLevel: index == levels.length - 1,
                      busy: _startingRating != null,
                      starting: _startingRating == item.rating,
                      onPlay: () => _startLevel(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignHeader extends StatelessWidget {
  const _CampaignHeader({required this.humanSide, required this.onSideChanged});

  final Side humanSide;
  final ValueChanged<Side>? onSideChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.flag, color: colors.onPrimary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A escalada dos nove Maias',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Faça 2 vitórias em qualquer janela de 3 partidas '
                      'avaliadas para abrir o próximo nível.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Jogar de', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<Side>(
            segments: const [
              ButtonSegment(
                value: Side.white,
                icon: Icon(Icons.circle_outlined),
                label: Text('Brancas'),
              ),
              ButtonSegment(
                value: Side.black,
                icon: Icon(Icons.circle),
                label: Text('Pretas'),
              ),
            ],
            selected: {humanSide},
            onSelectionChanged: onSideChanged == null
                ? null
                : (selection) => onSideChanged!(selection.first),
          ),
        ],
      ),
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
    final accent = completed
        ? colors.tertiary
        : progress.unlocked
        ? colors.primary
        : colors.outline;
    final status = !progress.unlocked
        ? 'Bloqueado'
        : completed
        ? finalLevel
              ? 'Campanha concluída'
              : 'Etapa concluída'
        : '${progress.validWins}/${progress.winsRequired} vitórias • '
              '${progress.gamesInWindow}/${progress.windowSize} partidas';

    return Semantics(
      label: 'Maia ${progress.rating}, $status',
      child: Card(
        elevation: progress.unlocked ? 1 : 0,
        color: progress.unlocked
            ? colors.surfaceContainer
            : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: completed
                    ? Icon(Icons.check, color: accent)
                    : progress.unlocked
                    ? Text(
                        '${progress.rating ~/ 100}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Icon(Icons.lock_outline, color: accent),
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
                            'Maia ${progress.rating}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFamily: 'serif',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (progress.unlocked)
                          Icon(
                            completed
                                ? Icons.workspace_premium
                                : Icons.lock_open,
                            color: accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: accent,
                      ),
                    ),
                    if (progress.unlocked) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: (progress.validWins / progress.winsRequired)
                                .clamp(0, 1)
                                .toDouble(),
                          ),
                          duration: AppMotion.slow,
                          curve: AppMotion.curve,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                minHeight: 7,
                                value: value,
                                color: accent,
                                backgroundColor: accent.withValues(alpha: 0.12),
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: busy ? null : onPlay,
                          icon: AnimatedSwitcher(
                            duration: AppMotion.fast,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: starting
                                ? const SizedBox.square(
                                    key: ValueKey('level-starting-spinner'),
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_arrow,
                                    key: ValueKey('level-starting-icon'),
                                  ),
                          ),
                          label: Text(
                            completed ? 'Jogar novamente' : 'Jogar etapa',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
