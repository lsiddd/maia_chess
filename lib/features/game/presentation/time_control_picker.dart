import 'package:flutter/material.dart';

import '../application/time_control.dart';

/// Shared configuration for local games, free play, and the campaign.
class TimeControlPicker extends StatelessWidget {
  const TimeControlPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TimeControl value;
  final ValueChanged<TimeControl>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time control',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
              isExpanded: true,
              initialValue: value.enabled,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: const [
                DropdownMenuItem(
                  value: false,
                  child: Text(
                    'Unlimited time',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(value: true, child: Text('Clock')),
              ],
              onChanged: onChanged == null
                  ? null
                  : (enabled) => onChanged!(value.copyWith(enabled: enabled)),
            ),
            if (value.enabled) ...[
              const SizedBox(height: 20),
              Text('Minutes per player: ${value.minutes}'),
              Slider(
                key: const Key('time-minutes'),
                value: value.minutes.toDouble(),
                max: 180,
                divisions: 180,
                label: '${value.minutes} min',
                semanticFormatterCallback: (v) =>
                    '${v.round()} minutes per player',
                onChanged: onChanged == null
                    ? null
                    : (v) => onChanged!(value.copyWith(minutes: v.round())),
              ),
              Text('Increment in seconds: ${value.incrementSeconds}'),
              Slider(
                key: const Key('time-increment'),
                value: value.incrementSeconds.toDouble(),
                max: 180,
                divisions: 180,
                label: '${value.incrementSeconds} s',
                semanticFormatterCallback: (v) =>
                    '${v.round()} seconds per move',
                onChanged: onChanged == null
                    ? null
                    : (v) => onChanged!(
                        value.copyWith(incrementSeconds: v.round()),
                      ),
              ),
              Text(
                !value.isValid
                    ? 'Choose minutes or an increment greater than zero.'
                    : value.minutes == 0
                    ? 'Each player starts with one increment.'
                    : 'The increment is added after each legal move.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: !value.isValid
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Clocks pause when you leave the game or background the app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<TimeControl?> showTimeControlDialog(BuildContext context) {
  var value = const TimeControl();
  return showDialog<TimeControl>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Local game'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: TimeControlPicker(
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
