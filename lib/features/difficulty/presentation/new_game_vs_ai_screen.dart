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
import '../../game/presentation/time_control_picker.dart';
import '../../game/application/time_control.dart';

/// Configure the human side and Maia-3 level for free play. Campaign selection
/// lives in `CampaignScreen`.
class NewGameVsAiScreen extends ConsumerStatefulWidget {
  const NewGameVsAiScreen({super.key});

  @override
  ConsumerState<NewGameVsAiScreen> createState() => _NewGameVsAiScreenState();
}

class _NewGameVsAiScreenState extends ConsumerState<NewGameVsAiScreen> {
  Side _humanSide = Side.white;
  TimeControl _timeControl = const TimeControl();
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
    if (_starting || _leaving || !_timeControl.isValid) return;
    setState(() => _starting = true);
    final request = _startRequest = GameStartRequest();
    final controller = ref.read(gameControllerProvider.notifier);
    try {
      final pending = _pendingStart = controller.startVsAi(
        humanSide: _humanSide,
        levelRating: _levelRating,
        timeControl: _timeControl,
        request: request,
      );
      final started = await pending;
      if (!mounted || request.isCancelled || _leaving) return;
      _startRequest = null;
      if (!started) {
        final error =
            ref.read(gameControllerProvider).engineError ??
            ref.read(gameControllerProvider).persistenceError ??
            'Could not start the Maia-3 engine.';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaffold = Scaffold(
      appBar: AppBar(title: const Text('Play against Maia-3')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: MaxWidthBody(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'A game at your level.',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Choose your challenge. Hints are available while you play.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionLabel(icon: Icons.swap_horiz, label: 'Your side'),
              const SizedBox(height: AppSpacing.m),
              SegmentedButton<Side>(
                direction: MediaQuery.textScalerOf(context).scale(14) > 20
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
                onSelectionChanged: _starting
                    ? null
                    : (selection) =>
                          setState(() => _humanSide = selection.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionLabel(
                icon: Icons.psychology_outlined,
                label: 'Your opponent',
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Higher ratings offer a stronger challenge.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              _RatingPicker(
                selectedRating: _levelRating,
                onChanged: _starting
                    ? null
                    : (rating) => setState(() => _levelRating = rating),
              ),
              const SizedBox(height: AppSpacing.xl),
              TimeControlPicker(
                value: _timeControl,
                onChanged: _starting
                    ? null
                    : (value) => setState(() => _timeControl = value),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.m,
                  AppSpacing.xl,
                  AppSpacing.l,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Maia-3 $_levelRating · '
                      '${_humanSide == Side.white ? 'White' : 'Black'} · '
                      '${timeControlLabel(_timeControl)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    FilledButton.icon(
                      onPressed: _starting || !_timeControl.isValid
                          ? null
                          : _start,
                      icon: _starting
                          ? const SizedBox.square(
                              key: ValueKey('starting-spinner'),
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(
                        _starting ? 'Preparing your game…' : 'Start game',
                        key: const ValueKey('starting-label'),
                      ),
                    ),
                    if (_starting) ...[
                      const SizedBox(height: AppSpacing.s),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'The first game may take a few seconds to prepare.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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

/// Fixed cells preserve the player's spatial map when a selection changes.
/// Measuring the label lets large system text reduce columns without shrinking.
class _RatingPicker extends StatelessWidget {
  const _RatingPicker({required this.selectedRating, required this.onChanged});

  final int selectedRating;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.chipTheme.labelStyle ?? theme.textTheme.labelLarge;
    final labelMeasure = TextPainter(
      text: TextSpan(text: '2600', style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final minimumWidth = (labelMeasure.width + 40).clamp(76.0, double.infinity);
    labelMeasure.dispose();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + AppSpacing.s) /
                    (minimumWidth + AppSpacing.s))
                .floor()
                .clamp(1, 4);
        final width =
            (constraints.maxWidth - AppSpacing.s * (columns - 1)) / columns;
        return Wrap(
          key: const Key('rating-options'),
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.xs,
          children: [
            for (final level in DifficultyLevel.all)
              SizedBox(
                width: width,
                child: ChoiceChip(
                  key: ValueKey('level-${level.rating}'),
                  showCheckmark: false,
                  labelPadding: EdgeInsets.zero,
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        child: selectedRating == level.rating
                            ? const ExcludeSemantics(
                                child: Icon(Icons.check, size: 18),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text('${level.rating}'),
                    ],
                  ),
                  selected: selectedRating == level.rating,
                  onSelected: onChanged == null
                      ? null
                      : (_) => onChanged!(level.rating),
                ),
              ),
          ],
        );
      },
    );
  }
}
