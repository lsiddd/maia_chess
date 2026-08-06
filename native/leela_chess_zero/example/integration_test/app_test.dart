import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:leela_chess_zero/lc0.dart';
import 'package:leela_chess_zero_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verify state', (tester) async {
    await tester.runAsync(() async {
      app.main();
      await tester.pumpAndSettle();

      // 5s should be enough for the engine to init itself
      // even on the slowest devices...
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    _expectState(tester, Lc0State.ready);

    await tester.enterText(find.byType(TextField), 'quit');
    tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
    _expectState(tester, Lc0State.disposed);
  });
}

void _expectState(WidgetTester tester, Lc0State state) {
  final found = find.byKey(const ValueKey('lc0.state')).evaluate();
  expect(found.length, equals(1));

  final widget = found.first.widget as Text;
  expect(widget.data, 'lc0.state=$state');
}
