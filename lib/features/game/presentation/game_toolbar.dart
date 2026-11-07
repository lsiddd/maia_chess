import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theming/app_theme.dart';

/// Keep the menu reachable while enlarged labels can scroll at their full size.
class GameActionBar extends StatelessWidget {
  const GameActionBar({super.key, required this.tools, required this.more});

  final List<GameToolButton> tools;
  final GameToolButton more;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!;
    final scaler = MediaQuery.textScalerOf(context);
    Size labelSize(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final sizes = [
      ...tools,
      more,
    ].map((tool) => labelSize(tool.label)).toList();
    final height = math.max(
      64.0,
      sizes.map((size) => size.height).reduce(math.max) + 38,
    );
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / (tools.length + 1);
          final widths = sizes
              .map((size) => math.max(math.max(48.0, slot), size.width + 12))
              .toList();
          return Row(
            key: const Key('game-actions'),
            children: [
              Expanded(
                child: CustomScrollView(
                  key: const Key('game-tools-scroll'),
                  scrollDirection: Axis.horizontal,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          for (var i = 0; i < tools.length; i++)
                            SizedBox(width: widths[i], child: tools[i]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: widths.last, child: more),
            ],
          );
        },
      ),
    );
  }
}

class GameToolButton extends StatelessWidget {
  const GameToolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active,
    this.loading = false,
    this.tooltip,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool? active;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = onPressed == null
        ? colors.onSurface.withValues(alpha: .38)
        : active == true
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      toggled: active,
      label: tooltip ?? label,
      value: loading ? 'Loading' : null,
      child: Tooltip(
        message: tooltip ?? label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Material(
            color: active == true
                ? colors.secondaryContainer
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              side: BorderSide(
                color: active == true ? colors.primary : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.small),
              onTap: onPressed,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 22,
                        child: loading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : Icon(icon, size: 22, color: foreground),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        label,
                        maxLines: 1,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
