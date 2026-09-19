import 'dart:ui' show SemanticsAction, Tristate;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/presentation/board_accessibility.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

void main() {
  for (final example in [
    (
      fen: 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
      uci: 'e1g1',
      text: 'Rei branco, roque pequeno.',
    ),
    (
      fen: 'r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1',
      uci: 'e8c8',
      text: 'Rei preto, roque grande.',
    ),
    (
      fen: '7k/P7/8/8/8/8/8/7K w - - 0 1',
      uci: 'a7a8n',
      text: 'Peão branco de a7 para a8, promove a Cavalo.',
    ),
  ]) {
    test('anúncio descreve ${example.uci}', () {
      final before = Chess.fromSetup(Setup.parseFen(example.fen));
      final move = NormalMove.fromUci(example.uci);
      final (after, san) = before.makeSan(move);
      final state = GameState.initial().copyWith(
        position: after as Chess,
        positionHistory: [before],
        uciHistory: [example.uci],
        sanHistory: [san],
        moveActorHistory: [GameMoveActor.player],
        moveTimeHistoryUtc: [DateTime.utc(2026)],
      );
      expect(lastMoveAnnouncement(state), example.text);
    });
  }
  Future<void> pumpGame(WidgetTester tester, {bool busy = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (busy) gameControllerProvider.overrideWith(_BusyController.new),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pump();
  }

  Finder square(String name) => find.byKey(ValueKey('board-semantics-$name'));

  Future<void> activate(WidgetTester tester, String name) async {
    final node = tester.getSemantics(square(name));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
  }

  for (final flipped in [false, true]) {
    testWidgets('joga por ações semânticas, invertido=$flipped', (
      tester,
    ) async {
      await pumpGame(tester);
      await tester.pumpAndSettle();
      if (flipped) {
        await tester.tap(find.byTooltip('Inverter tabuleiro'));
        await tester.pumpAndSettle();
      }
      for (final file in 'abcdefgh'.split('')) {
        for (var rank = 1; rank <= 8; rank++) {
          final name = '$file$rank';
          final node = tester.getSemantics(square(name));
          expect(node.label, startsWith('$name, '));
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
        }
      }
      expect(tester.getSemantics(square('e2')).label, 'e2, Peão branco');
      expect(tester.getSemantics(square('e4')).label, 'e4, vazia');
      await activate(tester, 'e2');
      expect(
        tester.getSemantics(square('e2')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        tester.getSemantics(square('e4')).value,
        contains('Destino legal'),
      );
      await activate(tester, 'e4');

      // A semântica usa a posição real, inclusive durante o voo visual.
      expect(tester.getSemantics(square('e2')).label, 'e2, vazia');
      expect(tester.getSemantics(square('e4')).label, 'e4, Peão branco');
      expect(find.bySemanticsLabel('Peão branco'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('e4'), findsOneWidget);
      final status = tester.getSemantics(find.byKey(const Key('turn-status')));
      expect(status.flagsCollection.isLiveRegion, isTrue);
      expect(status.label, contains('Peão branco de e2 para e4.'));
      expect(status.label, contains('Pretas jogam'));

      await activate(tester, 'd7');
      await activate(tester, 'd5');
      await tester.pumpAndSettle();
      await activate(tester, 'e4');
      await activate(tester, 'd5');
      await tester.pumpAndSettle();
      expect(find.text('exd5'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('turn-status'))).label,
        contains('Peão branco de e4 para d5, captura.'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('casas não oferecem ação durante pensamento da IA', (
    tester,
  ) async {
    await pumpGame(tester, busy: true);
    final node = tester.getSemantics(square('e2'));
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(node.label, 'e2, Peão branco');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

class _BusyController extends GameController {
  @override
  GameState build() =>
      GameState.initial().copyWith(aiSide: Side.white, aiThinking: true);
}
