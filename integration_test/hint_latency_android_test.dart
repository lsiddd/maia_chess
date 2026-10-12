import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/engine_ffi/lc0_engine/lc0_service.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_service.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';

import '../test/game_controller_test.dart' show FakeGameRepository;

// flutter drive --profile --no-dds --driver=test_driver/hint_latency.dart
//   --target=integration_test/hint_latency_android_test.dart -d DEVICE
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'profile: hint latency with real Android engines',
    (tester) async {
      final maia = Lc0Service();
      final stockfish = StockfishService();
      var backgroundWarmup = false;
      var gameId = 0;
      final container = ProviderContainer(
        overrides: [
          lc0EngineFactoryProvider.overrideWithValue(() => maia),
          stockfishEngineFactoryProvider.overrideWithValue(() => stockfish),
          stockfishWarmupEnabledProvider.overrideWith(
            (ref) => backgroundWarmup,
          ),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          gameIdFactoryProvider.overrideWithValue(
            () => 'benchmark-${gameId++}',
          ),
        ],
      );
      final controller = container.read(gameControllerProvider.notifier);
      final metrics = <String, Object>{
        'position': Chess.initial.fen,
        'maia_rating': 1100,
        'default_movetime_ms': StockfishEngine.defaultMovetimeMs,
      };

      Future<void> newGame() async {
        expect(
          await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
          isTrue,
          reason: container.read(gameControllerProvider).engineError,
        );
      }

      Future<double> measure(Future<void> Function() calculate) async {
        final watch = Stopwatch()..start();
        await calculate();
        watch.stop();
        return watch.elapsedMicroseconds / 1000;
      }

      Future<void> sequentialHint() async {
        // Reproduce the former hint implementation: Maia, Stockfish startup
        // when needed, then a 1500 ms search.
        final position = Chess.initial;
        final maiaUci = await maia.getBestMove(position.fen, nodes: 1);
        if (!stockfish.isReady) await stockfish.init();
        final stockfishUci = await stockfish.getBestMove(
          position.fen,
          movetimeMs: 1500,
        );
        for (final uci in [maiaUci, stockfishUci]) {
          final move = Move.parse(uci);
          expect(move, isNotNull);
          expect(position.isLegal(move!), isTrue);
        }
      }

      Future<void> optimizedHint() async {
        final hint = await controller.getHint();
        expect(hint.stockfishSan, isNotEmpty);
      }

      try {
        metrics['maia_initialization_ms'] = await measure(newGame);
        // Warm up Maia identically in both measurements with cold Stockfish.
        await maia.getBestMove(Chess.initial.fen, nodes: 1);
        metrics['sequential_cold_ms'] = await measure(sequentialHint);
        final sequentialWarm = <double>[];
        for (var sample = 0; sample < 3; sample++) {
          sequentialWarm.add(await measure(sequentialHint));
        }
        metrics['sequential_warm_ms'] = sequentialWarm;

        await stockfish.dispose();
        metrics['parallel_cold_ms'] = await measure(optimizedHint);
        metrics['cached_ms'] = await measure(optimizedHint);
        final parallelWarm = <double>[];
        for (var sample = 0; sample < 3; sample++) {
          // A new game invalidates the hint cache but reuses the engines.
          await newGame();
          parallelWarm.add(await measure(optimizedHint));
        }
        metrics['parallel_warm_ms'] = parallelWarm;
        metrics['parallel_1500ms_ms'] = await measure(() async {
          final hint = await controller.getHint(stockfishMovetimeMs: 1500);
          expect(hint.stockfishSan, isNotEmpty);
        });

        await stockfish.dispose();
        backgroundWarmup = true;
        container.invalidate(stockfishWarmupEnabledProvider);
        metrics['background_preparation_ms'] = await measure(() async {
          await newGame();
          final deadline = Stopwatch()..start();
          while (!stockfish.isReady) {
            if (deadline.elapsed > const Duration(seconds: 60)) {
              fail('Stockfish warmup did not finish in time');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        metrics['prepared_first_hint_ms'] = await measure(optimizedHint);
        binding.reportData = {'hint_latency': metrics};
        debugPrint('HINT_LATENCY ${jsonEncode(metrics)}');
      } finally {
        await controller.shutdownEngines();
        await stockfish.dispose();
        container.dispose();
      }
    },
    skip: !kProfileMode,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
