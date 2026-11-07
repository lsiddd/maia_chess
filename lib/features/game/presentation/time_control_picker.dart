import 'package:flutter/material.dart';

import '../../../core/theming/app_theme.dart';
import '../application/time_control.dart';

/// Shared configuration for local games, free play, and the campaign.
class TimeControlPicker extends StatelessWidget {
  const TimeControlPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.framed = true,
  });

  final bool framed;
  final TimeControl value;
  final ValueChanged<TimeControl>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time control', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Set your own pace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            children: [
              for (final enabled in [false, true])
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      value.enabled == enabled
                          ? Icons.check
                          : enabled
                          ? Icons.timer_outlined
                          : Icons.all_inclusive,
                      size: 18,
                    ),
                    label: Text(enabled ? 'Clock' : 'Unlimited time'),
                    selected: value.enabled == enabled,
                    onSelected: onChanged == null
                        ? null
                        : (_) => onChanged!(value.copyWith(enabled: enabled)),
                  ),
                ),
            ],
          ),
          if (!value.enabled)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Text(
                'Take as long as you need for each move.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (value.enabled) ...[
            const SizedBox(height: AppSpacing.l),
            Text('Quick choices', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                for (final preset in const [(3, 2), (5, 0), (10, 0), (15, 10)])
                  Semantics(
                    label:
                        '${preset.$1} minutes per player, '
                        '${preset.$2} seconds added per move',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: SizedBox.square(
                          dimension: 18,
                          child:
                              value.minutes == preset.$1 &&
                                  value.incrementSeconds == preset.$2
                              ? const Icon(Icons.check, size: 18)
                              : null,
                        ),
                        label: Text('${preset.$1} + ${preset.$2}'),
                        selected:
                            value.minutes == preset.$1 &&
                            value.incrementSeconds == preset.$2,
                        onSelected: onChanged == null
                            ? null
                            : (_) => onChanged!(
                                value.copyWith(
                                  minutes: preset.$1,
                                  incrementSeconds: preset.$2,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            _TimeAdjustment(
              label: 'Minutes per player',
              value: value.minutes,
              unit: 'min',
              sliderKey: const Key('time-minutes'),
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(value.copyWith(minutes: v)),
            ),
            const SizedBox(height: AppSpacing.s),
            _TimeAdjustment(
              label: 'Seconds added per move',
              value: value.incrementSeconds,
              unit: 'sec',
              sliderKey: const Key('time-increment'),
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(value.copyWith(incrementSeconds: v)),
            ),
            const SizedBox(height: AppSpacing.s),
            Semantics(
              liveRegion: !value.isValid,
              child: Text(
                !value.isValid
                    ? 'Choose minutes or an increment greater than zero.'
                    : value.minutes == 0
                    ? 'Each player starts with one increment.'
                    : 'The increment is added after each legal move.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: !value.isValid
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Clocks pause when you leave the game or background the app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
    return framed ? Card(margin: EdgeInsets.zero, child: content) : content;
  }
}

/// The slider provides fast changes; the buttons make exact values reachable
/// without requiring precise dragging or opening a keyboard.
class _TimeAdjustment extends StatelessWidget {
  const _TimeAdjustment({
    required this.label,
    required this.value,
    required this.unit,
    required this.sliderKey,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String unit;
  final Key sliderKey;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      Row(
        children: [
          IconButton(
            tooltip: 'Decrease $label',
            onPressed: onChanged == null || value == 0
                ? null
                : () => onChanged!(value - 1),
            icon: const Icon(Icons.remove),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          Expanded(
            child: Text(
              '$value $unit',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Increase $label',
            onPressed: onChanged == null || value == 180
                ? null
                : () => onChanged!(value + 1),
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
      Slider(
        key: sliderKey,
        value: value.toDouble(),
        max: 180,
        divisions: 180,
        label: '$value $unit',
        semanticFormatterCallback: (v) => '${v.round()} $label',
        onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
      ),
    ],
  );
}

String timeControlLabel(TimeControl value) => value.enabled
    ? '${value.minutes} + ${value.incrementSeconds}'
    : 'Unlimited time';

Future<TimeControl?> showTimeControlDialog(BuildContext context) {
  var value = const TimeControl();
  return showDialog<TimeControl>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Local game'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: TimeControlPicker(
              framed: false,
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: value.isValid
                ? () => Navigator.pop(context, value)
                : null,
            child: const Text('Start game'),
          ),
        ],
      ),
    ),
  );
}
