import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;
import 'support_game_settings.dart';

void main() {
  testWidgets('current position follows Maia replies in open history', (
    tester,
  ) async {
    final reply = Completer<String>();
    final settings = MemorySettings();
    addTearDown(settings.close);
    final c = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        maiaEngineFactoryProvider.overrideWithValue(
          () => FakeMaiaEngine(onMove: (_, _) => reply.future),
        ),
        maiaModelResolverProvider.overrideWithValue(() async => 'test.onnx'),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    final ctl = c.read(gameControllerProvider.notifier);
    await ctl.startVsAi(humanSide: Side.white, levelRating: 600);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final moving = ctl.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('move-list-panel')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Position 1 of 1'), findsOneWidget);
    reply.complete('e7e5');
    await tester.pump(const Duration(seconds: 2));
    await moving;
    await tester.pumpAndSettle();
    expect(c.read(gameControllerProvider).uciHistory, ['e2e4', 'e7e5']);
    await tester.tap(find.text('Current position'));
    await tester.pumpAndSettle();
    expect(find.text('Position 2 of 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
