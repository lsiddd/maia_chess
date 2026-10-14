import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/difficulty_levels.dart';
import '../../../core/theming/app_page_route.dart';
import '../../../core/theming/app_theme.dart';
import '../../../core/widgets/max_width_body.dart';
import '../../game/application/game_controller.dart';
import '../../game/presentation/game_screen.dart';

/// Configure the human side and Maia level for free play. Campaign selection
/// lives in `CampaignScreen`.
class NewGameVsAiScreen extends ConsumerStatefulWidget {
  const NewGameVsAiScreen({super.key});

  @override
  ConsumerState<NewGameVsAiScreen> createState() => _NewGameVsAiScreenState();
}

class _NewGameVsAiScreenState extends ConsumerState<NewGameVsAiScreen> {
  Side _humanSide = Side.white;
  int _levelRating = DifficultyLevel.all.first.rating;
  bool _starting = false;
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
      setState(() => _starting = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _start() async {
    if (_starting || _leaving) return;
    setState(() => _starting = true);
    final request = _startRequest = GameStartRequest();
    final controller = ref.read(gameControllerProvider.notifier);
    try {
      final pending = _pendingStart = controller.startVsAi(
        humanSide: _humanSide,
        levelRating: _levelRating,
        request: request,
      );
      final started = await pending;
      if (!mounted || request.isCancelled || _leaving) return;
      _startRequest = null;
      if (!started) {
        final error =
            ref.read(gameControllerProvider).engineError ??
            ref.read(gameControllerProvider).persistenceError ??
            'Could not start the Maia engine.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      await Navigator.of(
        context,
      ).push(AppPageRoute(builder: (_) => const GameScreen()));
    } catch (error) {
      if (!mounted || request.isCancelled || _leaving) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start the game: $error')),
      );
    } finally {
      _pendingStart = null;
      _startRequest = null;
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(title: const Text('Play against Maia')),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(
                      icon: Icons.swap_horiz,
                      label: 'Your side',
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SegmentedButton<Side>(
                      segments: const [
                        ButtonSegment(value: Side.white, label: Text('White')),
                        ButtonSegment(value: Side.black, label: Text('Black')),
                      ],
                      selected: {_humanSide},
                      onSelectionChanged: _starting
                          ? null
                          : (selection) =>
                                setState(() => _humanSide = selection.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(
                      icon: Icons.psychology_outlined,
                      label: 'Level (Maia style)',
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.s,
                      children: DifficultyLevel.all.map((level) {
                        final selected = level.rating == _levelRating;
                        return ChoiceChip(
                          label: Text('${level.rating}'),
                          selected: selected,
                          onSelected: _starting
                              ? null
                              : (_) =>
                                    setState(() => _levelRating = level.rating),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _starting ? null : _start,
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: _starting
                    ? const SizedBox(
                        key: ValueKey('starting-spinner'),
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start game', key: ValueKey('starting-label')),
              ),
            ),
            if (_starting) ...[
              const SizedBox(height: AppSpacing.m),
              Text(
                'Loading Maia $_levelRating weights... '
                'This may take a few seconds the first time.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
    return PopScope<void>(
      canPop: !_starting,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}
