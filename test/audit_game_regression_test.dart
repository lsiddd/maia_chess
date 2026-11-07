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
