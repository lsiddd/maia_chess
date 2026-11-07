import 'dart:async';
import 'dart:io' as io;
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/engine_ffi/maia_engine/verified_model_cache.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_persistence.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';
import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;

void main() {
  test(
    'verified model cache coalesces reads and revalidates changed files',
    () async {
      final directory = await io.Directory.systemTemp.createTemp(
        'model-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = io.File('${directory.path}/model');
      final cache = VerifiedModelCache();
      var checks = 0;
      Future<String> verify() async {
        checks++;
        await file.writeAsString('verified');
        return file.path;
      }

      await Future.wait([cache.resolve(verify), cache.resolve(verify)]);
      await cache.resolve(verify);
      expect(checks, 1);
      await file.writeAsString('corrupt');
      await cache.resolve(verify);
      expect(checks, 2);
      await file.delete();
      await cache.resolve(verify);
      expect(checks, 3);
    },
  );
  test(
    'persistence queue preserves order and recovers after failure',
    () async {
      final gate = Completer<void>();
      final persistence = GamePersistence(() => FakeGameRepository());
      final calls = <int>[];
      final first = persistence.enqueue(() async {
        await gate.future;
        calls.add(1);
        throw StateError('disk');
      });
      final failed = expectLater(first, throwsStateError);
      final second = persistence.enqueue(() async => calls.add(2));
      expect(calls, isEmpty);
      gate.complete();
      await failed;
      await second;
      await persistence.flush();
      expect(calls, [1, 2]);
    },
  );
  test(
    'leaving a session releases Maia and retains a restorable autosave',
    () async {
      final engine = FakeMaiaEngine(onMove: (_, _) async => 'e7e5');
      final repository = FakeGameRepository();
      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repository),
          maiaEngineFactoryProvider.overrideWithValue(() => engine),
          maiaModelResolverProvider.overrideWithValue(() async => 'model'),
          stockfishWarmupEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 600);
      final id = container.read(gameControllerProvider).gameId;
      await controller.releaseSessionResources();
      expect(engine.disposeCount, 1);
      expect((await repository.getActiveGame())!.id, id);
      expect(await controller.restoreActiveGame(), isTrue);
      expect(container.read(gameControllerProvider).gameId, id);
    },
  );
  test(
    'queued route disposal cannot release a newly started session',
    () async {
      final engine = FakeMaiaEngine(onMove: (_, _) async => 'e7e5');
      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          maiaEngineFactoryProvider.overrideWithValue(() => engine),
          maiaModelResolverProvider.overrideWithValue(() async => 'model'),
          stockfishWarmupEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 600);
      controller.releaseAfterNavigation();
      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 800),
        isTrue,
      );
      expect(engine.disposeCount, 0);
      expect(container.read(gameControllerProvider).levelRating, 800);
    },
  );

  test(
    'worker validates a long replay and rejects corrupted final FEN',
    () async {
      final moves = List.generate(
        40,
        (i) => '${i * 2 + 1}. Nf3 Nf6 ${i * 2 + 2}. Ng1 Ng8',
      ).join(' ');
      final game = const PgnService().parseImport(
        pgn: '$moves *',
        id: 'long',
        importedAtUtc: DateTime.utc(2026),
      );
      final replay = await const GameReplayer().replayAsync(game);
      expect(replay.positions.length, 161);
      expect(replay.positions.last.fen, game.currentFen);
      await expectLater(
        const GameReplayer().replayAsync(game.copyWith(currentFen: 'invalid')),
        throwsA(isA<GameReplayException>()),
      );
    },
  );
}
