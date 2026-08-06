// Cobre AUDITORIA_TECNICA.md, AUD-005: promotion_dialog.dart estava em 0%
// de cobertura.

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/game/presentation/promotion_dialog.dart';

void main() {
  testWidgets('mostra as quatro peças de promoção e retorna a escolhida', (
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

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Promover peão para'), findsOneWidget);
    expect(find.byTooltip('Dama'), findsOneWidget);
    expect(find.byTooltip('Torre'), findsOneWidget);
    expect(find.byTooltip('Bispo'), findsOneWidget);
    expect(find.byTooltip('Cavalo'), findsOneWidget);

    await tester.tap(find.byTooltip('Dama'));
    await tester.pumpAndSettle();

    expect(result, Role.queen);
    expect(find.text('Promover peão para'), findsNothing);
  });

  testWidgets('retorna null quando o jogador cancela tocando fora', (
    tester,
  ) async {
    Role? result = Role.pawn; // sentinela: deve virar null, não continuar pawn
    var completed = false;
    await tester.pumpWidget(
      _Harness(
        onPressed: (context) async {
          result = await showPromotionDialog(context, Side.black);
          completed = true;
        },
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Toque fora do AlertDialog, na barreira do modal.
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
            child: const Text('abrir'),
          ),
        ),
      ),
    );
  }
}
