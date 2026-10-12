import 'package:flutter/material.dart';

/// Fixed tool slots keep geometry stable during selection, loading, and
/// errors.
class GameToolButton extends StatelessWidget {
  const GameToolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.loading = false,
    this.tooltip,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        toggled: active,
        label: tooltip ?? label,
        child: Tooltip(
          message: tooltip ?? label,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: active
                  ? colors.secondaryContainer
                  : colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: active ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPressed,
                child: SizedBox(
                  height: 60,
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 22,
                          child: loading
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : Icon(
                                  icon,
                                  size: 22,
                                  color: onPressed == null
                                      ? colors.onSurface.withValues(alpha: .38)
                                      : colors.onSurface,
                                ),
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ],
                    ),
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
