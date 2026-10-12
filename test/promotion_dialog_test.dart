// Test promotion selection and cancellation.

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/game/presentation/promotion_dialog.dart';

void main() {
  testWidgets('shows all four promotion pieces and returns the selected role', (
    tester,
  ) async {
    Role? result;
    await tester.pumpWidget(
      _Harness(
        onPressed: (context) async {
          result = await showPromotionDialog(context, Side.white);
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Promote pawn to'), findsOneWidget);
    expect(find.byTooltip('Queen'), findsOneWidget);
    expect(find.byTooltip('Rook'), findsOneWidget);
    expect(find.byTooltip('Bishop'), findsOneWidget);
    expect(find.byTooltip('Knight'), findsOneWidget);

    await tester.tap(find.byTooltip('Queen'));
    await tester.pumpAndSettle();

    expect(result, Role.queen);
    expect(find.text('Promote pawn to'), findsNothing);
  });

  testWidgets('returns null when the player cancels by tapping outside', (
    tester,
  ) async {
    Role? result = Role
        .pawn; // Sentinel: cancellation must produce null rather than leave pawn.
    var completed = false;
    await tester.pumpWidget(
      _Harness(
        onPressed: (context) async {
          result = await showPromotionDialog(context, Side.black);
          completed = true;
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the modal barrier outside the AlertDialog.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.onPressed});

  final Future<void> Function(BuildContext) onPressed;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}
