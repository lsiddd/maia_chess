import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'game_controller_test.dart'
    show FakeGameRepository, FakeLc0Engine, FakeStockfishEngine;

void main() {
  test(
    'preparação em segundo plano não bloqueia partida nem duplica init',
    () async {
      final ready = Completer<void>();
      final maia = FakeLc0Engine(onMove: (_, _) async => 'e2e4');
      final stockfish = _DelayedStockfishEngine(ready.future);
      final container = _container(
        maiaFactory: () => maia,
        stockfishFactory: () => stockfish,
        warmup: true,
      );
      final controller = container.read(gameControllerProvider.notifier);

      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
        isTrue,
      );
      expect(ready.isCompleted, isFalse);
      expect(stockfish.initCount, 1);
      expect(container.read(gameControllerProvider).aiThinking, isFalse);
      expect(container.read(gameControllerProvider).hintThinking, isFalse);

      final hint = controller.getHint();
      await Future<void>.delayed(Duration.zero);
      expect(stockfish.initCount, 1);
      expect(stockfish.requestedFens, isEmpty);
      ready.complete();
      expect((await hint).stockfishSan, 'd4');
      expect(stockfish.initCount, 1);
    },
  );

  test(
    'falha na preparação não afeta a partida e a dica tenta de novo',
    () async {
      final maia = FakeLc0Engine(onMove: (_, _) async => 'e2e4');
      final stockfishEngines = <FakeStockfishEngine>[];
      final container = _container(
        maiaFactory: () => maia,
        stockfishFactory: () {
          final engine = FakeStockfishEngine(
            initError: stockfishEngines.isEmpty
                ? StateError('NNUE falhou')
                : null,
            onMove: (_, _) async => 'd2d4',
          );
          stockfishEngines.add(engine);
          return engine;
        },
        warmup: true,
      );
      final controller = container.read(gameControllerProvider.notifier);
      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(stockfishEngines.single.disposeCount, 1);
      expect(container.read(gameControllerProvider).engineError, isNull);
      expect(container.read(gameControllerProvider).evaluated, isTrue);
      expect(maia.isReady, isTrue);

      expect((await controller.getHint()).stockfishSan, 'd4');
      expect(stockfishEngines, hasLength(2));
      expect(maia.initPaths, hasLength(1));
    },
  );

  late FakeLc0Engine maia;
  late List<FakeStockfishEngine> engines;
  late ProviderContainer container;
  late GameController game;
  void setup(
    Future<String> Function(String, int) move, {
    Duration timeout = const Duration(seconds: 2),
  }) {
    maia = FakeLc0Engine(onMove: (_, _) async => 'e7e5');
    engines = [];
    container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        maiaWeightsResolverProvider.overrideWithValue(
          (level) async => level.weightsAsset,
        ),
        lc0EngineFactoryProvider.overrideWithValue(() => maia),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
        stockfishEngineFactoryProvider.overrideWithValue(() {
          final engine = FakeStockfishEngine(onMove: move);
          engines.add(engine);
          return engine;
        }),
        hintTotalTimeoutProvider.overrideWithValue(timeout),
      ],
    );
    game = container.read(gameControllerProvider.notifier);
    addTearDown(() async {
      await game.shutdownEngines();
      container.dispose();
    });
  }

  test(
    'dica usa somente Stockfish, valida origem e compartilha busca',
    () async {
      final reply = Completer<String>();
      setup((_, budget) {
        expect(budget, 500);
        return reply.future;
      });
      await game.startVsAi(humanSide: Side.white, levelRating: 1100);
      final first = game.getHint();
      expect(identical(first, game.getHint()), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(maia.requestedFens, isEmpty);
      reply.complete('d2d4');
      final hint = await first;
      expect(hint.move.from, Square.d2);
      expect(hint.stockfishSan, 'd4');
      expect(hint.fen, Chess.initial.fen);
      expect(container.read(gameControllerProvider).evaluated, isFalse);
      expect(
        (await container.read(gameRepositoryProvider).getActiveGame())!
            .evaluated,
        isFalse,
      );
      expect(identical(await game.getHint(), hint), isTrue);
      expect(engines.single.requestedFens, hasLength(1));
    },
  );
  test('cache distingue orçamento, posição e nova partida', () async {
    final budgets = <int>[];
    setup((fen, budget) async {
      budgets.add(budget);
      return fen == Chess.initial.fen ? 'd2d4' : 'g1f3';
    });
    await game.startVsAi(humanSide: Side.white, levelRating: 1100);
    await game.getHint();
    await game.getHint(stockfishMovetimeMs: 1500);
    await game.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    expect((await game.getHint()).move.from, Square.g1);
    await game.reset();
    await game.getHint();
    expect(budgets, [500, 1500, 500, 500]);
    expect(maia.requestedFens, hasLength(1));
  });
  test(
    'jogar cancela dica e ignora resposta atrasada sem descartar Maia',
    () async {
      final reply = Completer<String>();
      setup((_, _) => reply.future);
      await game.startVsAi(humanSide: Side.white, levelRating: 1100);
      final pending = game.getHint();
      final cancelled = expectLater(
        pending,
        throwsA(isA<HintCancelledException>()),
      );
      await Future<void>.delayed(Duration.zero);
      await game.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      await cancelled;
      reply.complete('d2d4');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(gameControllerProvider).uciHistory, [
        'e2e4',
        'e7e5',
      ]);
      expect(maia.disposeCount, 0);
      expect(engines.single.disposeCount, 1);
    },
  );
  test(
    'timeout descarta só Stockfish e nova busca recupera sem esperar a antiga',
    () async {
      final stuck = Completer<String>();
      var calls = 0;
      setup(
        (_, _) => ++calls == 1 ? stuck.future : Future.value('e2e4'),
        timeout: const Duration(milliseconds: 30),
      );
      await game.startVsAi(humanSide: Side.white, levelRating: 1100);
      await expectLater(game.getHint(), throwsA(isA<TimeoutException>()));
      expect((await game.getHint()).move.from, Square.e2);
      expect(maia.disposeCount, 0);
      expect(engines, hasLength(2));
      stuck.complete('d2d4');
    },
  );
  for (final invalid in ['invalid', 'e2e5']) {
    test('rejeita lance inválido $invalid e permite repetir', () async {
      var calls = 0;
      setup((_, _) async => ++calls == 1 ? invalid : 'e2e4');
      await expectLater(game.getHint(), throwsA(isA<StateError>()));
      expect((await game.getHint()).move.from, Square.e2);
      expect(maia.requestedFens, isEmpty);
    });
  }
  test('local e pretas recebem dica na posição e turno corretos', () async {
    setup(
      (fen, _) async => Chess.fromSetup(Setup.parseFen(fen)).turn == Side.white
          ? 'e2e4'
          : 'd7d5',
    );
    expect((await game.getHint()).move.from, Square.e2);
    await game.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    expect((await game.getHint()).move.from, Square.d7);
  });
}

ProviderContainer _container({
  required Lc0EngineFactory maiaFactory,
  required StockfishEngineFactory stockfishFactory,
  bool warmup = false,
}) {
  var gameId = 0;
  final container = ProviderContainer(
    overrides: [
      lc0EngineFactoryProvider.overrideWithValue(maiaFactory),
      stockfishEngineFactoryProvider.overrideWithValue(stockfishFactory),
      stockfishWarmupEnabledProvider.overrideWithValue(warmup),
      maiaWeightsResolverProvider.overrideWithValue(
        (level) async => level.weightsAsset,
      ),
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      gameIdFactoryProvider.overrideWithValue(() => 'hint-perf-${gameId++}'),
      hintTotalTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
    ],
  );
  addTearDown(() async {
    await container.read(gameControllerProvider.notifier).shutdownEngines();
    container.dispose();
  });
  return container;
}

class _DelayedStockfishEngine extends FakeStockfishEngine {
  _DelayedStockfishEngine(this.ready) : super(onMove: (_, _) async => 'd2d4');

  final Future<void> ready;
  int initCount = 0;

  @override
  Future<void> init() async {
    initCount++;
    await ready;
    await super.init();
  }
}
