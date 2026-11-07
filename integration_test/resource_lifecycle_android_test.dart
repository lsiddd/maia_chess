import 'dart:io';
import 'dart:convert';
import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_service.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native session releases memory and restores the same game', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final engines = <MaiaService>[];
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
        maiaEngineFactoryProvider.overrideWithValue(() {
          final engine = MaiaService();
          engines.add(engine);
          return engine;
        }),
      ],
    );
    final controller = container.read(gameControllerProvider.notifier);
    try {
      final before = ProcessInfo.currentRss;
      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
        isTrue,
      );
      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      final game = container.read(gameControllerProvider);
      expect(game.uciHistory.length, 2);
      final loaded = ProcessInfo.currentRss;
      await controller.releaseSessionResources();
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(engines.single.isReady, isFalse);
      final released = ProcessInfo.currentRss;
      final watch = Stopwatch()..start();
      expect(await controller.restoreActiveGame(), isTrue);
      expect(container.read(gameControllerProvider).gameId, game.gameId);
      expect(
        container.read(gameControllerProvider).uciHistory,
        game.uciHistory,
      );
      // Measurements are observations, not flaky thresholds on shared devices.
      // ignore: avoid_print
      print(
        'RESOURCE_LIFECYCLE ${jsonEncode({'before_rss': before, 'loaded_rss': loaded, 'released_rss': released, 'resume_ms': watch.elapsedMilliseconds})}',
      );
    } finally {
      await controller.shutdownEngines();
      container.dispose();
      await database.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
