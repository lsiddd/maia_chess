import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';

class _CheckedKingController extends GameController {
  _CheckedKingController(this.position);
  final Chess position;
  @override
  GameState build() => super.build().copyWith(position: position);
}

void main() {
  final positions = [
    '4r2k/8/8/8/8/8/8/4K3 w - - 0 1',
    '6r1/7k/8/8/8/8/6K1/8 w - - 0 1',
    '1r6/7k/8/8/8/8/1K6/8 w - - 0 1',
    '4k3/8/8/8/8/8/8/4R2K b - - 0 1',
    '8/6k1/8/8/8/8/7K/6R1 b - - 0 1',
    '8/1k6/8/8/8/8/7K/1R6 b - - 0 1',
    '6r1/7k/8/8/8/8/6K1/7r w - - 0 1',
    'R7/1k6/8/8/8/8/7K/1R6 b - - 0 1',
  ];
  for (final fen in positions) {
    final position = Chess.fromSetup(Setup.parseFen(fen));
    final from = position.board.kingOf(position.turn)!;
    final destinations = position.legalMoves[from]!.squares.toList();
    test(
      'destinos do rei em xeque preservam as fugas legais: ${from.name}',
      () {
        final state = GameState.initial().copyWith(position: position);
        expect(state.position.isCheck, isTrue);
        expect(state.isGameOver, isFalse);
        expect(
          state.legalDestinationsFrom(from),
          unorderedEquals(destinations),
        );
      },
    );
    for (final orientation in Side.values) {
      for (final drag in [false, true]) {
        testWidgets('rei ${from.name} foge do xeque: $orientation, arraste=$drag', (
          tester,
        ) async {
          for (final to in destinations) {
            final container = ProviderContainer(
              overrides: [
                gameControllerProvider.overrideWith(
                  () => _CheckedKingController(position),
                ),
              ],
            );
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: Scaffold(
                    body: SizedBox.square(
                      dimension: 320,
                      child: ChessBoardWidget(orientation: orientation),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            Finder cell(Square square) => find.byKey(
              ValueKey(
                'board-square-${orientation == Side.white ? 7 - square.rank.value : square.rank.value}-'
                '${orientation == Side.white ? square.file.value : 7 - square.file.value}',
              ),
            );
            if (drag) {
              final start = tester.getCenter(cell(from));
              final end = tester.getCenter(cell(to));
              final gesture = await tester.startGesture(start);
              for (var step = 1; step <= 10; step++) {
                await gesture.moveTo(Offset.lerp(start, end, step / 10)!);
                await tester.pump(const Duration(milliseconds: 16));
              }
              expect(find.byKey(const Key('board-drag-piece')), findsOneWidget);
              await gesture.up();
            } else {
              await tester.tap(cell(from));
              await tester.pump();
              await tester.tap(cell(to));
            }
            await tester.pumpAndSettle();
            final result = container.read(gameControllerProvider);
            expect(result.uciHistory, ['${from.name}${to.name}'], reason: fen);
            expect(result.position.board.kingOf(position.turn), to);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
          }
        });
      }
    }
  }
}
