import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/game/presentation/game_toolbar.dart';

void main() {
  testWidgets('only persistent tools announce a toggled state', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final example in [
        (label: 'Undo', active: null, expected: Tristate.none),
        (label: 'More', active: null, expected: Tristate.none),
        (label: 'Hint', active: false, expected: Tristate.isFalse),
        (label: 'Attacks', active: true, expected: Tristate.isTrue),
        (label: 'Plans', active: false, expected: Tristate.isFalse),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 100,
                  child: GameToolButton(
                    label: example.label,
                    icon: Icons.help_outline,
                    active: example.active,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final flags = tester
            .getSemantics(find.byType(GameToolButton))
            .flagsCollection;
        expect(flags.isButton, isTrue, reason: example.label);
        expect(flags.isToggled, example.expected, reason: example.label);
      }
    } finally {
      semantics.dispose();
    }
  });
}
