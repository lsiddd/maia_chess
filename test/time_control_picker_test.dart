import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/game/application/time_control.dart';
import 'package:maia_chess/features/game/presentation/time_control_picker.dart';

void main() {
  testWidgets('chooses unlimited or clock and retains slider values', (
    tester,
  ) async {
    var value = const TimeControl();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: TimeControlPicker(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.text('Unlimited time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clock').last);
    await tester.pumpAndSettle();
    expect(value.enabled, isTrue);
    expect(find.byType(Slider), findsNWidgets(2));
    tester.widget<Slider>(find.byKey(const Key('time-minutes'))).onChanged!(0);
    await tester.pump();
    expect(
      find.text('Choose minutes or an increment greater than zero.'),
      findsOneWidget,
    );
    tester.widget<Slider>(find.byKey(const Key('time-increment'))).onChanged!(
      5,
    );
    await tester.pump();
    expect(value.isValid, isTrue);
    expect(value.startingTimeMs, 5000);
    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlimited time').last);
    await tester.pumpAndSettle();
    expect(value.enabled, isFalse);
    expect(value.incrementSeconds, 5);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets(
    'local setup disables start for a zero clock and supports small screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTimeControlDialog(context),
                child: const Text('Configure'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlimited time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clock').last);
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byKey(const Key('time-minutes'))).onChanged!(
        0,
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start game'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
