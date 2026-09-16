import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/game/presentation/chess_piece_widget.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

/// Cobre as microinterações do tabuleiro que não dependem de motor algum:
/// destaque de lances legais ao selecionar uma peça, destaque do último
/// lance, destaque de xeque e a animação de "voo" da peça até a casa de
/// destino (em vez de ela simplesmente teletransportar). Tudo aqui é
/// alcançável só com toques — dispensa lc0/Stockfish reais.
void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: GameScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? squareColor(WidgetTester tester, String squareKey) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey(squareKey)),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  double indicatorOpacity(
    WidgetTester tester,
    String squareKey,
    String indicatorKey,
  ) {
    return tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byKey(ValueKey(squareKey)),
            matching: find.byKey(ValueKey(indicatorKey)),
          ),
        )
        .opacity;
  }

  testWidgets('selecionar uma peça mostra pontos nas casas de destino legais', (
    tester,
  ) async {
    await pumpGame(tester);

    // Antes de selecionar nada, nenhuma casa mostra o indicador.
    expect(
      indicatorOpacity(tester, 'board-square-4-4', 'legal-target-indicator'),
      0,
    );

    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pump();

    // e4 e e3 são destinos legais do peão em e2; d4 não é.
    expect(
      indicatorOpacity(tester, 'board-square-4-4', 'legal-target-indicator'),
      1,
    );
    expect(
      indicatorOpacity(tester, 'board-square-5-4', 'legal-target-indicator'),
      1,
    );
    expect(
      indicatorOpacity(tester, 'board-square-4-3', 'legal-target-indicator'),
      0,
    );

    // Desselecionar (toque na própria peça) apaga os indicadores de novo.
    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pumpAndSettle();
    expect(
      indicatorOpacity(tester, 'board-square-4-4', 'legal-target-indicator'),
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a origem e o destino do último lance ficam destacados', (
    tester,
  ) async {
    await pumpGame(tester);

    final untouchedBefore = squareColor(tester, 'board-square-6-0'); // a2
    final originBefore = squareColor(tester, 'board-square-6-4'); // e2
    expect(
      originBefore,
      untouchedBefore,
    ); // mesma cor de base (mesma "cor" de casa)

    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-4-4'))); // e4
    await tester.pumpAndSettle();

    final untouchedAfter = squareColor(
      tester,
      'board-square-6-0',
    ); // a2, não jogada
    final originAfter = squareColor(
      tester,
      'board-square-6-4',
    ); // e2, origem do lance
    final destinationAfter = squareColor(
      tester,
      'board-square-4-4',
    ); // e4, destino

    expect(originAfter, isNot(equals(untouchedAfter)));
    expect(destinationAfter, isNot(equals(untouchedAfter)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('o rei em xeque recebe um destaque próprio', (tester) async {
    await pumpGame(tester);

    // 1. e4 f6 2. Qh5+ — abre a diagonal d1-h5-e8 e dá xeque sem ser mate
    // (o negro ainda pode bloquear com g6), evitando o diálogo de fim de
    // jogo dentro deste teste.
    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-4-4'))); // e4
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('board-square-1-5'))); // f7
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-2-5'))); // f6
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('board-square-7-3'))); // d1
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-3-7'))); // h5
    await tester.pumpAndSettle();

    expect(find.text('Xeque'), findsOneWidget);
    expect(
      indicatorOpacity(
        tester,
        'board-square-0-4',
        'check-glow-indicator',
      ), // e8
      1,
    );
    expect(
      indicatorOpacity(
        tester,
        'board-square-7-4',
        'check-glow-indicator',
      ), // e1
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'o lance anima a peça deslizando até o destino em vez de teleportar',
    (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-4-4'))); // e4
      await tester
          .pump(); // um quadro: a animação de voo começou, ainda não terminou.

      // A casa de destino ainda não expõe sua própria peça estática — quem
      // está visível ali é a peça "voando" por cima, sem a key da casa. (A
      // casa de origem não entra nesta checagem porque o AnimatedSwitcher
      // mantém o filho anterior montado por mais um quadro mesmo com
      // duração zero — um detalhe interno da troca, não do voo em si.)
      expect(find.byKey(const ValueKey('board-piece-4-4')), findsNothing);

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('board-piece-4-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('board-piece-6-4')), findsNothing);
      expect(find.byType(ChessPieceWidget), findsNWidgets(32));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('arrastar uma peça até um destino legal joga o lance', (
    tester,
  ) async {
    await pumpGame(tester);
    final from = tester.getCenter(
      find.byKey(const ValueKey('board-square-6-4')),
    ); // e2
    final to = tester.getCenter(
      find.byKey(const ValueKey('board-square-4-4')),
    ); // e4

    final gesture = await tester.startGesture(from);
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('e4'), findsOneWidget);
    expect(find.byKey(const ValueKey('board-piece-6-4')), findsNothing);
    expect(find.byKey(const ValueKey('board-piece-4-4')), findsOneWidget);
    expect(find.byType(ChessPieceWidget), findsNWidgets(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'soltar o arraste num destino ilegal devolve a peça à própria casa',
    (tester) async {
      await pumpGame(tester);
      final from = tester.getCenter(
        find.byKey(const ValueKey('board-square-6-4')), // e2
      );
      // e5: 3 casas à frente, ilegal para o primeiro lance do peão.
      final illegalTo = tester.getCenter(
        find.byKey(const ValueKey('board-square-3-4')),
      );

      final gesture = await tester.startGesture(from);
      await tester.pump();
      await gesture.moveTo(illegalTo);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Ainda não houve nenhum lance.'), findsOneWidget);
      expect(find.byKey(const ValueKey('board-piece-6-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('board-piece-3-4')), findsNothing);
      expect(find.byType(ChessPieceWidget), findsNWidgets(32));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'arrastar uma nova peça funciona mesmo com o voo do lance anterior '
    'ainda em animação',
    (tester) async {
      await pumpGame(tester);

      // Primeiro lance por toque: e2-e4. Não usa `pumpAndSettle` depois —
      // fica com o voo de e2 até e4 ainda em andamento (dura AppMotion.slow,
      // 350ms) para reproduzir a janela em que o arraste era ignorado.
      await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('board-square-4-4'))); // e4
      await tester.pump(); // um quadro: o voo começou, ainda não terminou.

      // Com o voo do primeiro lance ainda rodando, arrasta uma segunda peça
      // (peão das pretas d7-d5). O arraste deve responder imediatamente: a
      // peça precisa aparecer seguindo o dedo (overlay de arraste montado).
      final from = tester.getCenter(
        find.byKey(const ValueKey('board-square-1-3')), // d7
      );
      final to = tester.getCenter(
        find.byKey(const ValueKey('board-square-3-3')), // d5
      );

      final gesture = await tester.startGesture(from);
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Antes da correção, `onPanStart` via o voo de e2-e4 ainda em
      // andamento e retornava sem nunca iniciar o arraste — d7 permaneceria
      // parado e nenhum lance seria registrado. Chegar a d5 prova que o
      // segundo arraste foi reconhecido e completado normalmente.
      expect(find.byKey(const ValueKey('board-piece-1-3')), findsNothing);
      expect(find.byKey(const ValueKey('board-piece-3-3')), findsOneWidget);
      expect(find.byType(ChessPieceWidget), findsNWidgets(32));
      expect(tester.takeException(), isNull);
    },
  );
}
