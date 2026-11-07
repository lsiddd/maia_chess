import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_theme.dart';
import '../application/game_clock.dart';

class GameClocks extends ConsumerWidget {
  const GameClocks({super.key, required this.orientation});

  final Side orientation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(gameClockProvider);
    if (clock == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final side in [orientation, orientation.opposite])
            Expanded(
              child: _ClockFace(
                side: side,
                remainingMs: side == Side.white ? clock.whiteMs : clock.blackMs,
                active: clock.runningSide == side,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClockFace extends StatelessWidget {
  const _ClockFace({
    required this.side,
    required this.remainingMs,
    required this.active,
  });

  final Side side;
  final int remainingMs;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = (remainingMs / 1000).ceil();
    final label = side == Side.white ? 'White' : 'Black';
    final time =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      label: '$label, $time${active ? ', clock running' : ''}',
      excludeSemantics: true,
      child: Container(
        key: ValueKey('clock-${side.name}'),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: MediaQuery.textScalerOf(context).scale(14) >= 22
            ? Tooltip(
                message: label,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: side == Side.white
                            ? Colors.white
                            : const Color(0xFF202D26),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        time,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: remainingMs < 10000
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label  ',
                      style: theme.textTheme.labelSmall,
                    ),
                    TextSpan(text: time),
                  ],
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: remainingMs < 10000
                      ? theme.colorScheme.error
                      : active
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
