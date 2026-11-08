import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;

class SlowInit extends FakeMaiaEngine {
  SlowInit() : super(onMove: (_, _) async => 'e2e4');
  final reached = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> init(String path) async {
    reached.complete();
    await release.future;
    await super.init(path);
  }

  @override
  Future<void> dispose() async {
    await release.future;
    await super.dispose();
  }
}

void main() {
  const now = 0;
  ProviderContainer setup(FakeGameRepository repo, {FakeMaiaEngine? engine}) {
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repo),
        maiaEngineFactoryProvider.overrideWithValue(
          () => engine ?? FakeMaiaEngine(onMove: (_, _) async => 'e7e5'),
        ),
        maiaModelResolverProvider.overrideWithValue(() async => 'test.onnx'),
        clockNowMsProvider.overrideWithValue(() => now),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets(
    'stalled engine startup reports a timeout and allows local chess',
    (tester) async {
      final engine = SlowInit();
      final c = setup(FakeGameRepository(), engine: engine);
      final ctl = c.read(gameControllerProvider.notifier);
      final starting = ctl.startVsAi(humanSide: Side.white, levelRating: 600);
      await tester.pump();
      expect(engine.reached.isCompleted, isTrue);
      await tester.pump(const Duration(seconds: 31));
      expect(await starting, isFalse);
      expect(
        c.read(gameControllerProvider).engineError,
        contains('TimeoutException'),
      );
      await ctl.startTwoPlayers();
      expect(c.read(gameControllerProvider).gameId, isNotNull);
      engine.release.complete();
      await tester.pump();
    },
  );

  test('cancelled Maia startup does not block local chess', () async {
    final engine = SlowInit();
    final c = setup(FakeGameRepository(), engine: engine);
    final ctl = c.read(gameControllerProvider.notifier);
    final request = GameStartRequest();
    final ai = ctl.startVsAi(
      humanSide: Side.white,
      levelRating: 600,
      request: request,
    );
    await engine.reached.future;
    request.cancel();
    expect(await ai, isFalse);
    var finished = false;
    final local = ctl.startTwoPlayers().then((_) => finished = true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(finished, isTrue);
    engine.release.complete();
    await local;
  });
}
