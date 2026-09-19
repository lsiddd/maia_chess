import 'package:maia_chess/data/providers.dart';
import 'game_controller_test.dart' show FakeGameRepository;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';
import 'package:maia_chess/features/game/presentation/chess_piece_widget.dart';

class _PositionController extends GameController {
  _PositionController(this.position);
  final Chess position;
  @override
  GameState build() => super.build().copyWith(position: position);
}

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Chess? position,
    ValueNotifier<Side>? orientation,
  }) async {
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        if (position != null)
          gameControllerProvider.overrideWith(
            () => _PositionController(position),
          ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox.square(
              dimension: 400,
              child: orientation == null
                  ? const ChessBoardWidget()
                  : ValueListenableBuilder<Side>(
                      valueListenable: orientation,
                      builder: (_, side, _) =>
                          ChessBoardWidget(orientation: side),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder square(int row, int col) =>
      find.byKey(ValueKey('board-square-$row-$col'));
  final slide = find.byKey(const Key('board-slide-layer'));
  final rookSlide = find.byKey(const Key('board-rook-slide-layer'));
  final drag = find.byKey(const Key('board-drag-layer'));

  for (final cancel in ['flip', 'background', 'reset', 'move', 'pointer']) {
    testWidgets('arraste cancelado com segurança: $cancel', (tester) async {
      final orientation = ValueNotifier(Side.white);
      addTearDown(orientation.dispose);
      final container = await mount(tester, orientation: orientation);
      final controller = container.read(gameControllerProvider.notifier);
      final gesture = await tester.startGesture(tester.getCenter(square(6, 4)));
      await gesture.moveTo(tester.getCenter(square(4, 4)));
      await tester.pump();
      expect(drag, findsOneWidget);
      switch (cancel) {
        case 'flip':
          orientation.value = Side.black;
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        case 'reset':
          await controller.reset();
        case 'move':
          await controller.attemptDragMove(
            Square.e2,
            Square.e4,
            onPromotion: () async => null,
          );
        case 'pointer':
          await gesture.cancel();
      }
      await tester.pump();
      expect(drag, findsNothing);
      if (cancel != 'pointer') {
        await gesture.moveBy(const Offset(0, -30));
        await gesture.up();
      }
      await tester.pumpAndSettle();
      expect(
        container.read(gameControllerProvider).uciHistory.length,
        cancel == 'move' ? 1 : 0,
      );
      expect(tester.takeException(), isNull);
      if (cancel == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    });
  }

  testWidgets('retorno ilegal parte da soltura, sem peça duplicada na origem', (
    tester,
  ) async {
    await mount(tester);
    final origin = tester.getCenter(square(6, 4));
    final release = tester.getCenter(square(3, 4));
    final gesture = await tester.startGesture(origin);
    await gesture.moveTo(release);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pump();
    Finder flyingPiece() =>
        find.descendant(of: slide, matching: find.byType(ChessPieceWidget));
    expect(tester.getCenter(flyingPiece()), release);
    expect(find.byKey(const ValueKey('board-piece-6-4')), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getCenter(flyingPiece()).dy, greaterThan(release.dy));
    expect(tester.getCenter(flyingPiece()).dy, lessThan(origin.dy));
    await tester.pumpAndSettle();
    expect(slide, findsNothing);
    expect(find.byType(ChessPieceWidget), findsNWidgets(32));
  });

  for (final side in [Side.white, Side.black]) {
    for (final queenSide in [false, true]) {
      testWidgets(
        'roque sincroniza rei e torre: $side, longo=$queenSide; undo limpa voo',
        (tester) async {
          final position = Chess.fromSetup(
            Setup.parseFen(
              'r3k2r/8/8/8/8/8/8/R3K2R ${side == Side.white ? 'w' : 'b'} KQkq - 0 1',
            ),
          );
          final container = await mount(tester, position: position);
          final controller = container.read(gameControllerProvider.notifier);
          final row = side == Side.white ? 7 : 0;
          await controller.attemptDragMove(
            side == Side.white ? Square.e1 : Square.e8,
            Square.fromCoords(
              File(queenSide ? 2 : 6),
              Rank(side == Side.white ? 0 : 7),
            ),
            onPromotion: () async => null,
          );
          await tester.pump();
          expect(slide, findsOneWidget);
          expect(rookSlide, findsOneWidget);
          Offset center(Finder layer) => tester.getCenter(
            find.descendant(of: layer, matching: find.byType(ChessPieceWidget)),
          );
          final kingStart = center(slide);
          final rookStart = center(rookSlide);
          await tester.pump(const Duration(milliseconds: 100));
          final kingEnd = tester.getCenter(square(row, queenSide ? 2 : 6));
          final rookEnd = tester.getCenter(square(row, queenSide ? 3 : 5));
          final kingProgress =
              (center(slide).dx - kingStart.dx) / (kingEnd.dx - kingStart.dx);
          final rookProgress =
              (center(rookSlide).dx - rookStart.dx) /
              (rookEnd.dx - rookStart.dx);
          expect(kingProgress, greaterThan(0));
          expect(kingProgress, lessThan(1));
          expect(kingProgress, closeTo(rookProgress, 0.0001));
          await controller.undo();
          await tester.pump();
          expect(slide, findsNothing);
          expect(rookSlide, findsNothing);
          await tester.pumpAndSettle();
          expect(
            container.read(gameControllerProvider).position.fen,
            position.fen,
          );
          expect(find.byType(ChessPieceWidget), findsNWidgets(6));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
