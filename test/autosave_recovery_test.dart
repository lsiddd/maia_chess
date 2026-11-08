import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;

class SaveFailure extends FakeGameRepository {
  bool fail = false;
  @override
  Future<void> saveOngoing(StoredGame game) => fail
      ? Future.error(StateError('disk temporarily unavailable'))
      : super.saveOngoing(game);
  @override
  Future<bool> completeGame(StoredGame game) => fail
      ? Future.error(StateError('disk temporarily unavailable'))
      : super.completeGame(game);
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

  Future<void> move(GameController controller, String uci) {
    final m = NormalMove.fromUci(uci);
    return controller.attemptDragMove(
      m.from,
      m.to,
      onPromotion: () async => null,
    );
  }

  test('active autosave stores moves without regenerating PGN', () async {
    final repo = SaveFailure();
    final c = setup(repo);
    final ctl = c.read(gameControllerProvider.notifier);
    await ctl.startTwoPlayers();
    await move(ctl, 'e2e4');
    expect(repo.games.values.single.moves.single.uci, 'e2e4');
    expect(repo.games.values.single.pgn, isNull);
  });

  test('a failed retry preserves the latest in-memory position', () async {
    final repo = SaveFailure();
    final c = setup(repo);
    final ctl = c.read(gameControllerProvider.notifier);
    await ctl.startTwoPlayers();
    repo.fail = true;
    await move(ctl, 'e2e4');
    expect(await ctl.restoreActiveGame(), isFalse);
    expect(c.read(gameControllerProvider).uciHistory, ['e2e4']);
    expect(c.read(gameControllerProvider).persistenceError, isNotNull);
  });

  test('retries unsaved moves before restoring', () async {
    final repo = SaveFailure();
    final c = setup(repo);
    final ctl = c.read(gameControllerProvider.notifier);
    await ctl.startTwoPlayers();
    repo.fail = true;
    await move(ctl, 'e2e4');
    expect(c.read(gameControllerProvider).uciHistory, ['e2e4']);
    expect(c.read(gameControllerProvider).persistenceError, isNotNull);
    ctl.setClockPaused(true);
    await ctl.flushPersistence();
    repo.fail = false;
    await ctl.restoreActiveGame();
    expect(c.read(gameControllerProvider).uciHistory, ['e2e4']);
  });
  test('retries resignation without reviving a completed game', () async {
    final repo = SaveFailure();
    final c = setup(repo);
    final ctl = c.read(gameControllerProvider.notifier);
    await ctl.startVsAi(
      humanSide: Side.white,
      levelRating: 600,
      campaignMode: true,
    );
    repo.fail = true;
    await ctl.resign();
    expect(c.read(gameControllerProvider).isGameOver, isTrue);
    repo.fail = false;
    await ctl.restoreActiveGame();
    expect(c.read(gameControllerProvider).isGameOver, isTrue);
  });
}
