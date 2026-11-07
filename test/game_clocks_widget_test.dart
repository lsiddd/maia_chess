import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/time_control.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

import 'game_controller_test.dart' show FakeGameRepository;
import 'support_game_settings.dart';

void main() {
  for (final size in [
    const Size(320, 480),
    const Size(800, 400),
    const Size(600, 320),
  ]) {
    testWidgets('clocks fit at $size and pause with the app lifecycle', (
      tester,
    ) async {
      var now = 0;
      final settings = MemorySettings();
      final repository = FakeGameRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          gameRepositoryProvider.overrideWithValue(repository),
          clockNowMsProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(settings.close);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startTwoPlayers(
        timeControl: const TimeControl(
          enabled: true,
          minutes: 5,
          incrementSeconds: 3,
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const GameScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('White'), findsOneWidget);
      expect(find.text('5:00'), findsNWidgets(2));
      expect(find.byTooltip('Black'), findsOneWidget);
      final board = tester.getRect(find.byKey(const Key('chess-board')));
      expect(board.width, greaterThan(150));
      expect(board.width, closeTo(board.height, .01));
      now = 2000;
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('4:58'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await controller.flushPersistence();
      expect(repository.games.values.single.whiteTimeMs, 298000);
      now += 60000;
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(gameClockProvider)!.whiteMs, 298000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      now += 1000;
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('4:57'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.flushPersistence();
      expect(container.read(gameClockProvider)!.runningSide, isNull);
      expect(repository.games.values.single.whiteTimeMs, 297000);
    });
  }
}
