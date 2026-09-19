// Cobre AUDITORIA_TECNICA.md, AUD-005: hint_dialog.dart estava em 0% de
// cobertura, sem nenhum teste para os três estados do FutureBuilder
// interno (carregando, sucesso, erro).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/hints/domain/hint_result.dart';
import 'package:maia_chess/features/hints/presentation/hint_dialog.dart';

void main() {
  testWidgets('dica fechada antes do primeiro build observa erro tardio', (
    tester,
  ) async {
    final calculation = Completer<HintResult>();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('origem'))),
    );
    final context = tester.element(find.text('origem'));
    final dialog = showHintDialog(context, calculation.future);
    Navigator.of(context).pop();
    calculation.completeError(StateError('cancelado antes do build'));
    await tester.pumpAndSettle();
    await dialog;
    expect(tester.takeException(), isNull);
  });

  for (final close in ['button', 'outside', 'back']) {
    testWidgets('fechar dica cancela cálculo: $close', (tester) async {
      final calculation = Completer<HintResult>();
      var cancelled = 0;
      await tester.pumpWidget(
        _Harness(
          onPressed: (context) => showHintDialog(
            context,
            calculation.future,
            onClosed: () async {
              cancelled++;
              calculation.completeError(StateError('cancelado'));
            },
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      switch (close) {
        case 'button':
          await tester.tap(find.text('Fechar'));
        case 'outside':
          await tester.tapAt(const Offset(5, 5));
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(cancelled, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mostra o indicador de progresso enquanto a dica calcula', (
    tester,
  ) async {
    final completer = Completer<HintResult>();
    await tester.pumpWidget(
      _Harness(
        onPressed: (context) => showHintDialog(context, completer.future),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const HintResult(levelRating: 1500, maiaSan: 'e4', stockfishSan: 'Nf3'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('mostra o lance do Maia e do Stockfish lado a lado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        onPressed: (context) => showHintDialog(
          context,
          Future.value(
            const HintResult(
              levelRating: 1500,
              maiaSan: 'e4',
              stockfishSan: 'Nf3',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Estilo Maia 1500'), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('Melhor lance (Stockfish)'), findsOneWidget);
    expect(find.text('Nf3'), findsOneWidget);
  });

  testWidgets('mostra mensagem de erro quando a dica falha', (tester) async {
    await tester.pumpWidget(
      _Harness(
        onPressed: (context) {
          // `.ignore()` só evita que a zona de teste reporte este erro como
          // "não tratado" antes do FutureBuilder se inscrever nele; o
          // próprio FutureBuilder recebe e trata o erro normalmente.
          final failing = Future<HintResult>.error(
            StateError('motor indisponível'),
          )..ignore();
          return showHintDialog(context, failing);
        },
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não foi possível calcular a dica.'),
      findsOneWidget,
    );
    expect(find.textContaining('motor indisponível'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
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
