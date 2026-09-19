import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';

void main() {
  testWidgets('mover o dedo não reconstrói as 64 casas', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox.square(dimension: 320, child: ChessBoardWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('board-square-6-4'))),
    );
    final target = tester.getCenter(
      find.byKey(const ValueKey('board-square-4-4')),
    );
    await gesture.moveTo(target);
    await tester.pumpAndSettle();
    var squareBuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (element.widget.runtimeType.toString() == '_SquareVisual') {
        squareBuilds++;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    for (var frame = 0; frame < 30; frame++) {
      await gesture.moveTo(target + Offset(frame.isEven ? 4 : -4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = previous;
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(
      squareBuilds,
      0,
      reason: '30 atualizações do ponteiro durante o mesmo arraste',
    );
  });
}
