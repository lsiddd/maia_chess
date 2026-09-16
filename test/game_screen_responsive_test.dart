import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/game/presentation/chess_piece_widget.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

void main() {
  Future<void> pumpGameAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('paisagem limita o tabuleiro pela altura e usa painel lateral', (
    tester,
  ) async {
    await pumpGameAt(tester, const Size(800, 400));

    final boardRect = tester.getRect(find.byKey(const Key('chess-board')));
    final movesRect = tester.getRect(find.byKey(const Key('move-list-panel')));

    expect(tester.takeException(), isNull);
    expect(boardRect.width, closeTo(boardRect.height, 0.01));
    expect(boardRect.height, lessThanOrEqualTo(320));
    expect(boardRect.right, lessThan(movesRect.left));
    expect(find.text('Brancas jogam'), findsOneWidget);
    expect(find.text('Jogadas'), findsOneWidget);
    expect(find.text('Ainda não houve nenhum lance.'), findsOneWidget);
  });

  testWidgets('as 64 casas são uniformes e as peças usam 78% da célula', (
    tester,
  ) async {
    await pumpGameAt(tester, const Size(400, 800));

    final boardSize = tester.getSize(find.byKey(const Key('chess-board')));
    Size? referenceSquare;
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final squareSize = tester.getSize(
          find.byKey(ValueKey('board-square-$row-$col')),
        );
        referenceSquare ??= squareSize;
        expect(squareSize.width, closeTo(referenceSquare.width, 0.01));
        expect(squareSize.height, closeTo(referenceSquare.height, 0.01));
        expect(squareSize.width, closeTo(squareSize.height, 0.01));
      }
    }

    expect(referenceSquare!.width, closeTo(boardSize.width / 8, 0.01));
    expect(find.byType(ChessPieceWidget), findsNWidgets(32));
    final pieceSize = tester.getSize(
      find.byKey(const ValueKey('board-piece-0-0')),
    );
    expect(pieceSize.width, closeTo(referenceSquare.width * 0.78, 0.01));
    expect(pieceSize.height, closeTo(referenceSquare.height * 0.78, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desfazer comunica estado desabilitado e reiniciar confirma', (
    tester,
  ) async {
    await pumpGameAt(tester, const Size(400, 800));

    final undo = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Desfazer'),
    );
    expect(undo.onPressed, isNull);

    await tester.tap(find.text('Reiniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Reiniciar partida?'), findsOneWidget);
    expect(
      find.text('O progresso atual desta partida será perdido.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'toques continuam mapeando origem e destino após o redimensionamento',
    (tester) async {
      await pumpGameAt(tester, const Size(400, 800));

      await tester.tap(find.byKey(const ValueKey('board-square-6-4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-4-4')));
      await tester.pumpAndSettle();

      expect(find.text('e4'), findsOneWidget);
      expect(find.byKey(const ValueKey('board-piece-6-4')), findsNothing);
      expect(find.byKey(const ValueKey('board-piece-4-4')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tela baixa com fonte ampliada usa rolagem sem overflow', (
    tester,
  ) async {
    await pumpGameAt(tester, const Size(320, 480), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('Brancas jogam'), findsOneWidget);
    expect(find.text('Reiniciar'), findsOneWidget);
  });

  testWidgets('a lista destaca o lance mais recente e o realce acompanha', (
    tester,
  ) async {
    await pumpGameAt(tester, const Size(400, 800));

    Iterable<String> highlightedMoves() => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byKey(const Key('move-list-panel')),
            matching: find.byType(Container),
          ),
        )
        .map((container) => ((container.child as Text?)?.data ?? '').trim())
        .where((text) => text.isNotEmpty);

    // 1. e4
    await tester.tap(find.byKey(const ValueKey('board-square-6-4')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-4-4')));
    await tester.pumpAndSettle();

    expect(highlightedMoves(), ['e4']);

    // 1... e5: o realce passa para o lance das pretas.
    await tester.tap(find.byKey(const ValueKey('board-square-1-4')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-3-4')));
    await tester.pumpAndSettle();

    expect(highlightedMoves(), ['e5']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botão de inverter troca a perspectiva do tabuleiro', (
    tester,
  ) async {
    await pumpGameAt(tester, const Size(400, 800));

    // Antes de inverter: perspectiva das brancas, então a1 (canto inferior
    // esquerdo do tabuleiro) fica na última linha/coluna exibida.
    expect(find.byKey(const ValueKey('board-piece-7-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-piece-0-0')), findsOneWidget);

    await tester.tap(find.byTooltip('Inverter tabuleiro'));
    await tester.pumpAndSettle();

    // Depois de inverter, a torre branca de a1 passa a aparecer no topo
    // esquerdo (linha 0) em vez do canto inferior esquerdo (linha 7): a
    // perspectiva virou.
    final flippedCorner = tester.widget<Semantics>(
      find.descendant(
        of: find.byKey(const ValueKey('board-piece-0-0')),
        matching: find.byType(Semantics),
      ),
    );
    expect(flippedCorner.properties.label, contains('branc'));
    expect(tester.takeException(), isNull);
  });
}
