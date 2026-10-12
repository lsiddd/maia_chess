import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/game/presentation/chess_piece_widget.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

/// Board interaction tests without native engines: legal destinations,
/// last-move and check highlights, and piece flight animations.
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

  testWidgets('selecting a piece shows dots on legal destination squares', (
    tester,
  ) async {
    await pumpGame(tester);

    // Before selection, no square shows a legal-move indicator.
    expect(
      indicatorOpacity(tester, 'board-square-4-4', 'legal-target-indicator'),
      0,
    );

    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pump();

    // e4 and e3 are legal pawn destinations from e2; d4 is not.
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

    // Tapping the selected piece again clears the indicators.
    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pumpAndSettle();
    expect(
      indicatorOpacity(tester, 'board-square-4-4', 'legal-target-indicator'),
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the origin and destination of the last move are highlighted', (
    tester,
  ) async {
    await pumpGame(tester);

    final untouchedBefore = squareColor(tester, 'board-square-6-0'); // a2
    final originBefore = squareColor(tester, 'board-square-6-4'); // e2
    expect(originBefore, untouchedBefore); // Same underlying square colour.

    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-4-4'))); // e4
    await tester.pumpAndSettle();

    final untouchedAfter = squareColor(
      tester,
      'board-square-6-0',
    ); // a2, not played
    final originAfter = squareColor(
      tester,
      'board-square-6-4',
    ); // e2, move origin
    final destinationAfter = squareColor(
      tester,
      'board-square-4-4',
    ); // e4, destination

    expect(originAfter, isNot(equals(untouchedAfter)));
    expect(destinationAfter, isNot(equals(untouchedAfter)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the king in check receives its own highlight', (tester) async {
    await pumpGame(tester);

    // 1. e4 f6 2. Qh5+ opens the d1-h5-e8 diagonal. Black can block with g6,
    // avoiding the game-over dialog in this test.
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

    expect(find.text('Check'), findsOneWidget);
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

  testWidgets('the move animates the piece sliding to its destination', (
    tester,
  ) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-4-4'))); // e4
    await tester.pump(); // One frame: flight has started but not finished.

    // The destination static piece stays hidden while flight draws it above
    // the board without the square key. The origin is excluded because
    // AnimatedSwitcher keeps its old child mounted for one frame even with
    // zero duration.
    expect(find.byKey(const ValueKey('board-piece-4-4')), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('board-piece-4-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-piece-6-4')), findsNothing);
    expect(find.byType(ChessPieceWidget), findsNWidgets(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a gradual vertical drag takes priority over page scrolling', (
    tester,
  ) async {
    await pumpGame(tester);
    final from = tester.getCenter(
      find.byKey(const ValueKey('board-square-6-4')),
    );
    final to = tester.getCenter(find.byKey(const ValueKey('board-square-4-4')));
    final gesture = await tester.startGesture(from);
    for (var step = 1; step <= 40; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 40)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('board-drag-piece')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('board-piece-6-4')), findsNothing);
    expect(find.byKey(const ValueKey('board-piece-4-4')), findsOneWidget);
  });

  testWidgets('dragging a piece to a legal destination plays the move', (
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

    expect(find.text('1. e4'), findsOneWidget);
    expect(find.byKey(const ValueKey('board-piece-6-4')), findsNothing);
    expect(find.byKey(const ValueKey('board-piece-4-4')), findsOneWidget);
    expect(find.byType(ChessPieceWidget), findsNWidgets(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dropping on an illegal destination returns the piece to its square',
    (tester) async {
      await pumpGame(tester);
      final from = tester.getCenter(
        find.byKey(const ValueKey('board-square-6-4')), // e2
      );
      // e5 is three squares ahead, illegal for the first pawn move.
      final illegalTo = tester.getCenter(
        find.byKey(const ValueKey('board-square-3-4')),
      );

      final gesture = await tester.startGesture(from);
      await tester.pump();
      await gesture.moveTo(illegalTo);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Moves · No moves yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('board-piece-6-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('board-piece-3-4')), findsNothing);
      expect(find.byType(ChessPieceWidget), findsNWidgets(32));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dragging a new piece works while the previous move '
      'is still animating', (tester) async {
    await pumpGame(tester);

    // Play e2-e4 by tap without pumpAndSettle, leaving flight in progress
    // for AppMotion.slow (350 ms) to reproduce the formerly blocked drag
    // window.
    await tester.tap(find.byKey(const ValueKey('board-square-6-4'))); // e2
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-square-4-4'))); // e4
    await tester.pump(); // One frame: flight has started but not finished.

    // Drag Black d7-d5 while the first flight is active. The drag layer
    // must follow the finger immediately.
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
    final dragLayer = find.byKey(const Key('board-drag-layer'));
    final layers = tester
        .widget<Stack>(
          find.ancestor(of: dragLayer, matching: find.byType(Stack)).first,
        )
        .children;
    expect(find.byKey(const Key('board-slide-layer')), findsOneWidget);
    expect(layers.last.key, const Key('board-drag-layer'));
    await gesture.up();
    await tester.pumpAndSettle();

    // Completing d7-d5 proves a second drag is accepted before the previous
    // flight finishes.
    expect(find.byKey(const ValueKey('board-piece-1-3')), findsNothing);
    expect(find.byKey(const ValueKey('board-piece-3-3')), findsOneWidget);
    expect(find.byType(ChessPieceWidget), findsNWidgets(32));
    expect(tester.takeException(), isNull);
  });

  for (final flipped in [false, true]) {
    testWidgets(
      'drag enlarges the piece and highlights the square under the finger, flipped=$flipped',
      (tester) async {
        await pumpGame(tester);
        if (flipped) {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Rotate board'));
          await tester.pumpAndSettle();
        }
        Finder squareAt(int row, int col) => find.byKey(
          ValueKey(
            'board-square-${flipped ? 7 - row : row}-${flipped ? 7 - col : col}',
          ),
        );
        final origin = squareAt(6, 4); // e2
        final target = squareAt(4, 4); // e4
        final from = tester.getCenter(origin);
        final staticSize = tester.getSize(
          find.descendant(of: origin, matching: find.byType(ChessPieceWidget)),
        );
        final targetRect = tester.getRect(target);
        // Off-centre input detects any mismatch between artwork and target.
        final pointer = targetRect.topLeft + const Offset(6, 6);
        final gesture = await tester.startGesture(from);
        await tester.pump();
        await gesture.moveTo(pointer);
        await tester.pump();
        final highlight = find.byKey(const Key('board-drag-target'));
        final dragged = find.byKey(const Key('board-drag-piece'));
        expect(tester.getRect(highlight), targetRect);
        expect(tester.getSize(dragged).width, greaterThan(staticSize.width));
        expect(tester.getCenter(dragged), pointer);

        final invalid = squareAt(
          3,
          4,
        ); // e5 is illegal but still under the finger.
        await gesture.moveTo(tester.getCenter(invalid));
        await tester.pump();
        expect(tester.getRect(highlight), tester.getRect(invalid));
        final board = tester.getRect(find.byKey(const Key('chess-board')));
        await gesture.moveTo(Offset(board.right + 10, pointer.dy));
        await tester.pump();
        expect(highlight, findsNothing);

        await gesture.moveTo(pointer);
        await tester.pump();
        expect(tester.getRect(highlight), targetRect);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(highlight, findsNothing);
        expect(dragged, findsNothing);
        expect(find.text('1. e4'), findsOneWidget);
        expect(
          find.descendant(of: target, matching: find.byType(ChessPieceWidget)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    for (final selection in ['none', 'same piece', 'another piece']) {
      testWidgets(
        'drag selects and keeps destinations when returning to the origin: '
        '$selection, flipped=$flipped',
        (tester) async {
          await pumpGame(tester);
          if (flipped) {
            await tester.tap(find.text('More'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Rotate board'));
            await tester.pumpAndSettle();
          }
          String keyAt(int row, int col) =>
              'board-square-${flipped ? 7 - row : row}-'
              '${flipped ? 7 - col : col}';
          final originKey = keyAt(6, 4); // e2
          final targetKey = keyAt(4, 4); // e4
          final oldTargetKey = keyAt(
            5,
            0,
          ); // a3, destination of the knight on b1
          if (selection != 'none') {
            await tester.tap(
              find.byKey(
                ValueKey(selection == 'same piece' ? originKey : keyAt(7, 1)),
              ),
            );
            await tester.pumpAndSettle();
          }
          final from = tester.getCenter(find.byKey(ValueKey(originKey)));
          final to = tester.getCenter(find.byKey(ValueKey(targetKey)));
          final gesture = await tester.startGesture(from);
          await tester.pump();
          await gesture.moveTo(to);
          await tester.pump();

          void expectPawnSelected() {
            expect(
              indicatorOpacity(tester, targetKey, 'legal-target-indicator'),
              1,
            );
            expect(
              indicatorOpacity(tester, oldTargetKey, 'legal-target-indicator'),
              0,
            );
            expect(
              squareColor(tester, originKey),
              isNot(squareColor(tester, keyAt(6, 2))),
            );
          }

          expectPawnSelected();
          await gesture.moveTo(from);
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();
          expectPawnSelected();
          expect(find.text('Moves · No moves yet'), findsOneWidget);

          // After returning the piece, tapping the destination is enough to
          // play.
          await tester.tap(find.byKey(ValueKey(targetKey)));
          await tester.pumpAndSettle();
          expect(find.text('1. e4'), findsOneWidget);
          expect(
            indicatorOpacity(tester, targetKey, 'legal-target-indicator'),
            0,
          );
          expect(find.byType(ChessPieceWidget), findsNWidgets(32));
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final kingSide in [false, true]) {
      testWidgets(
        'dropping beyond the ${kingSide ? 'h' : 'a'} edge does not play a move '
        'with the board ${flipped ? 'invertido' : 'normal'}',
        (tester) async {
          await pumpGame(tester);
          if (flipped) {
            await tester.tap(find.text('More'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Rotate board'));
            await tester.pumpAndSettle();
          }

          final fromRow = flipped ? 0 : 7;
          final fromCol = flipped ? (kingSide ? 1 : 6) : (kingSide ? 6 : 1);
          final toRow = flipped ? 2 : 5;
          final toCol = flipped ? (kingSide ? 0 : 7) : (kingSide ? 7 : 0);
          final from = tester.getCenter(
            find.byKey(ValueKey('board-square-$fromRow-$fromCol')),
          );
          final legalTo = tester.getCenter(
            find.byKey(ValueKey('board-square-$toRow-$toCol')),
          );
          final board = tester.getRect(find.byKey(const Key('chess-board')));
          // The exact right edge and a point beyond the left edge are outside.
          // Both were previously clamped to legal destinations.
          final outside = Offset(
            toCol == 0 ? board.left - 8 : board.right,
            legalTo.dy,
          );

          final gesture = await tester.startGesture(from);
          await gesture.moveTo(legalTo);
          await tester.pump();
          await gesture.moveTo(outside);
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();

          expect(find.text('Moves · No moves yet'), findsOneWidget);
          expect(
            find.byKey(ValueKey('board-piece-$fromRow-$fromCol')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey('board-piece-$toRow-$toCol')),
            findsNothing,
          );
          expect(find.byType(ChessPieceWidget), findsNWidgets(32));
          expect(tester.takeException(), isNull);

          // Cancellation must still allow moving the same piece later.
          final nextGesture = await tester.startGesture(from);
          await tester.pump();
          await nextGesture.moveTo(legalTo);
          await tester.pump();
          await nextGesture.up();
          await tester.pumpAndSettle();
          expect(find.text(kingSide ? '1. Nh3' : '1. Na3'), findsOneWidget);
          expect(
            find.byKey(ValueKey('board-piece-$toRow-$toCol')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
