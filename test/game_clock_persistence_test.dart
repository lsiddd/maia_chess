import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'package:maia_chess/features/game/application/time_control.dart';
import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;

class DelayedSave extends FakeGameRepository {
  final reached = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> saveOngoing(StoredGame game) async {
    if (game.moves.length == 2) {
      if (!reached.isCompleted) reached.complete();
      await release.future;
    }
    await super.saveOngoing(game);
  }
}

void main() {
  var now = 0;
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

  Future<void> move(GameController controller, String uci) {
    final m = NormalMove.fromUci(uci);
    return controller.attemptDragMove(
      m.from,
      m.to,
      onPromotion: () async => null,
    );
  }

  testWidgets('human clock waits until AI save releases the board', (
    tester,
  ) async {
    now = 0;
    final repo = DelayedSave();
    final c = setup(repo);
    final ctl = c.read(gameControllerProvider.notifier);
    await ctl.startVsAi(
      humanSide: Side.white,
      levelRating: 600,
      timeControl: const TimeControl(enabled: true, minutes: 1),
    );
    final moving = move(ctl, 'e2e4');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1101));
    expect(repo.reached.isCompleted, isTrue);
    expect(c.read(gameControllerProvider).position.turn, Side.white);
    expect(c.read(gameControllerProvider).aiThinking, isTrue);
    expect(ctl.selectForDrag(Square.g1), isFalse);
    now = 5000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(gameClockProvider)!.runningSide, isNull);
    expect(c.read(gameClockProvider)!.whiteMs, 60000);
    repo.release.complete();
    await moving;
    expect(c.read(gameClockProvider)!.runningSide, Side.white);
    expect(c.read(gameControllerProvider).aiThinking, isFalse);
    ctl.setClockPaused(true);
  });
}
