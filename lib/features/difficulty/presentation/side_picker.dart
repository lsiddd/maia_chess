import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

enum SideChoice {
  white('White', Icons.circle_outlined),
  black('Black', Icons.circle),
  random('Random', Icons.shuffle);

  const SideChoice(this.label, this.icon);
  final String label;
  final IconData icon;

  Side resolve() => switch (this) {
    white => Side.white,
    black => Side.black,
    random => Random().nextBool() ? Side.white : Side.black,
  };
}

class SidePicker extends StatelessWidget {
  const SidePicker({super.key, required this.value, required this.onChanged});

  final SideChoice value;
  final ValueChanged<SideChoice>? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SegmentedButton<SideChoice>(
      direction:
          MediaQuery.textScalerOf(context).scale(14) > 20 ||
              constraints.maxWidth < 300
          ? Axis.vertical
          : Axis.horizontal,
      segments: [
        for (final choice in SideChoice.values)
          ButtonSegment(
            value: choice,
            icon: Icon(choice.icon),
            label: Text(choice.label),
          ),
      ],
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.single),
    ),
  );
}
