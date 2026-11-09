import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/time_control.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;

void main() {
  for (final ai in [false, true]) {
    test('${ai ? 'AI' : 'Local'} reset publishes only after commit', () async {
      final repository = _ControlledBeginRepository();
      var now = 0;
      var nextId = 0;
      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repository),
          gameIdFactoryProvider.overrideWithValue(() => 'game-${nextId++}'),
          clockNowMsProvider.overrideWithValue(() => now),
          maiaEngineFactoryProvider.overrideWithValue(
            () => FakeMaiaEngine(onMove: (_, _) async => 'e7e5'),
          ),
          maiaModelResolverProvider.overrideWithValue(() async => 'test.onnx'),
          stockfishWarmupEnabledProvider.overrideWithValue(false),
        ],
      );
      final controller = container.read(gameControllerProvider.notifier);
      addTearDown(() async {
        await controller.shutdownEngines();
        container.dispose();
      });
      const timeControl = TimeControl(enabled: true, minutes: 1);
      if (ai) {
        await controller.startVsAi(
          humanSide: Side.white,
          levelRating: 1100,
          campaignMode: true,
          timeControl: timeControl,
        );
      } else {
        await controller.startTwoPlayers(timeControl: timeControl);
      }
      now = 2000;
      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      final before = container.read(gameControllerProvider);
      final saved = repository.games.values.single;
      repository.fail = true;
      final gate = repository.gate = Completer<void>();
      final resetting = controller.reset();
      await repository.reached.future;
      expect(container.read(gameControllerProvider).gameId, before.gameId);
      expect(container.read(gameControllerProvider).position, before.position);
      expect(repository.games.values.single, same(saved));

      now += 10000;
      gate.complete();
      await resetting;
      final failed = container.read(gameControllerProvider);
      expect(failed.persistenceError, contains('begin failed'));
      expect(failed.gameId, before.gameId);
      expect(failed.startedAtUtc, before.startedAtUtc);
      expect(failed.position, before.position);
      expect(failed.uciHistory, before.uciHistory);
      expect(failed.evaluated, before.evaluated);
      expect(failed.aiSide, before.aiSide);
      expect(failed.levelRating, before.levelRating);
      expect(failed.campaignMode, before.campaignMode);
      expect(failed.whiteTimeMs, before.whiteTimeMs);
      expect(failed.blackTimeMs, before.blackTimeMs);
      expect(
        container.read(gameClockProvider)!.runningSide,
        before.position.turn,
      );
      expect(repository.games.values.single, same(saved));

      repository.fail = false;
      repository.reached = Completer<void>();
      final successGate = repository.gate = Completer<void>();
      final retrying = controller.reset();
      await repository.reached.future;
      expect(container.read(gameControllerProvider).gameId, before.gameId);
      expect(container.read(gameControllerProvider).position, before.position);
      expect(repository.games.values.single, same(saved));
      successGate.complete();
      await retrying;
      final restarted = container.read(gameControllerProvider);
      expect(restarted.gameId, isNot(before.gameId));
      expect(restarted.position, Chess.initial);
      expect(restarted.uciHistory, isEmpty);
      expect(restarted.persistenceError, isNull);
      expect(restarted.aiSide, before.aiSide);
      expect(restarted.levelRating, before.levelRating);
      expect(restarted.campaignMode, before.campaignMode);
      expect(restarted.whiteTimeMs, 60000);
      expect(restarted.blackTimeMs, 60000);
      expect(repository.games.values.single.id, restarted.gameId);
    });
  }

  test(
    'a move supersedes a pending reset without replacing its autosave',
    () async {
      final repository = _ControlledBeginRepository();
      final container = ProviderContainer(
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startTwoPlayers();
      final id = container.read(gameControllerProvider).gameId;
      final gate = repository.gate = Completer<void>();
      final resetting = controller.reset();
      await repository.reached.future;
      final moving = controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      gate.complete();
      await resetting;
      await moving;
      expect(container.read(gameControllerProvider).gameId, id);
      expect(container.read(gameControllerProvider).uciHistory, ['e2e4']);
      expect(repository.games.values.single.id, id);
      expect(repository.games.values.single.moves.single.uci, 'e2e4');
    },
  );
}

class _ControlledBeginRepository extends FakeGameRepository {
  bool fail = false;
  Completer<void>? gate;
  var reached = Completer<void>();

  @override
  Future<void> beginGame(StoredGame game, {bool Function()? canCommit}) async {
    if (gate != null) {
      if (!reached.isCompleted) reached.complete();
      await gate!.future;
    }
    if (fail) throw StateError('begin failed');
    await super.beginGame(game, canCommit: canCommit);
  }
}
