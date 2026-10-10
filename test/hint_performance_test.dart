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

  test(
    'Maia e Stockfish calculam em paralelo com busca padrão de 500ms',
    () async {
      final maiaStarted = Completer<void>();
      final stockfishStarted = Completer<void>();
      final maiaReply = Completer<String>();
      final stockfishReply = Completer<String>();
      final maia = FakeLc0Engine(
        onMove: (_, nodes) {
          expect(nodes, 1);
          maiaStarted.complete();
          return maiaReply.future;
        },
      );
      final stockfish = FakeStockfishEngine(
        onMove: (_, movetimeMs) {
          expect(movetimeMs, 500);
          stockfishStarted.complete();
          return stockfishReply.future;
        },
      );
      final container = _container(
        maiaFactory: () => maia,
        stockfishFactory: () => stockfish,
      );
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 1100);

      final hint = controller.getHint();
      // Nenhum motor responde antes de ambos iniciarem: uma implementação
      // sequencial não consegue passar por esta barreira.
      await Future.wait([maiaStarted.future, stockfishStarted.future]);
      expect(maia.requestedFens.single, stockfish.requestedFens.single);
      stockfishReply.complete('d2d4');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(gameControllerProvider).hintThinking, isTrue);
      maiaReply.complete('e2e4');

      final result = await hint;
      expect(result.maiaSan, 'e4');
      expect(result.stockfishSan, 'd4');
      expect(container.read(gameControllerProvider).hintThinking, isFalse);
    },
  );

  test(
    'reabrir dica reutiliza resultado e respeita o tempo de análise',
    () async {
      final budgets = <int>[];
      final maia = FakeLc0Engine(onMove: (_, _) async => 'e2e4');
      final stockfish = FakeStockfishEngine(
        onMove: (_, movetimeMs) async {
          budgets.add(movetimeMs);
          return 'd2d4';
        },
      );
      final container = _container(
        maiaFactory: () => maia,
        stockfishFactory: () => stockfish,
      );
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 1100);

      final first = await controller.getHint();
      await controller.cancelHint(); // fechar uma dica concluída mantém o cache
      final repeated = await controller.getHint();
      expect(identical(first, repeated), isTrue);
      expect(maia.requestedFens, hasLength(1));
      expect(stockfish.requestedFens, hasLength(1));
      expect(container.read(gameControllerProvider).evaluated, isFalse);

      final longer = await controller.getHint(stockfishMovetimeMs: 1500);
      expect(identical(first, longer), isFalse);
      expect(
        identical(longer, await controller.getHint(stockfishMovetimeMs: 1500)),
        isTrue,
      );
      expect(budgets, [500, 1500]);
      expect(maia.requestedFens, hasLength(2));
      expect(maia.initPaths, hasLength(1));
    },
  );

  test('uma posição diferente recebe uma dica nova', () async {
    final maia = FakeLc0Engine(
      onMove: (fen, _) async {
        final position = Chess.fromSetup(Setup.parseFen(fen));
        return position.turn == Side.black ? 'e7e5' : 'd2d4';
      },
    );
    final stockfish = FakeStockfishEngine(
      onMove: (fen, _) async {
        final position = Chess.fromSetup(Setup.parseFen(fen));
        return position.board.pieceAt(Square.e4) == null ? 'e2e4' : 'g1f3';
      },
    );
    final container = _container(
      maiaFactory: () => maia,
      stockfishFactory: () => stockfish,
    );
    final controller = container.read(gameControllerProvider.notifier);
    await controller.startVsAi(humanSide: Side.white, levelRating: 1100);
    expect((await controller.getHint()).stockfishSan, 'e4');

    await controller.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    expect((await controller.getHint()).stockfishSan, 'Nf3');
    expect(stockfish.requestedFens.toSet(), hasLength(2));
    expect(maia.requestedFens, hasLength(3)); // duas dicas e a resposta da IA
  });

  test('nova partida e novo nível não reutilizam uma dica antiga', () async {
    final maia = FakeLc0Engine(onMove: (_, _) async => 'e2e4');
    final stockfish = FakeStockfishEngine(onMove: (_, _) async => 'd2d4');
    final container = _container(
      maiaFactory: () => maia,
      stockfishFactory: () => stockfish,
    );
    final controller = container.read(gameControllerProvider.notifier);

    for (final level in [1100, 1100, 1900]) {
      await controller.startVsAi(humanSide: Side.white, levelRating: level);
      expect(container.read(gameControllerProvider).evaluated, isTrue);
      expect((await controller.getHint()).levelRating, level);
      expect(container.read(gameControllerProvider).evaluated, isFalse);
      expect(
        (await container.read(gameRepositoryProvider).getActiveGame())!
            .evaluated,
        isFalse,
      );
    }
    expect(stockfish.requestedFens, hasLength(3));
    expect(stockfish.requestedFens.toSet(), hasLength(1));
    expect(maia.requestedFens, hasLength(3));
  });

  test('falha do Stockfish encerra dica sem esperar um Maia preso', () async {
    final lateReply = Completer<String>();
    final maiaEngines = <FakeLc0Engine>[];
    final stockfishEngines = <FakeStockfishEngine>[];
    final container = _container(
      maiaFactory: () {
        final first = maiaEngines.isEmpty;
        final engine = FakeLc0Engine(
          onMove: (_, _) => first ? lateReply.future : Future.value('e2e4'),
        );
        maiaEngines.add(engine);
        return engine;
      },
      stockfishFactory: () {
        final first = stockfishEngines.isEmpty;
        final engine = FakeStockfishEngine(
          onMove: (_, _) async {
            if (first) throw StateError('busca Stockfish falhou');
            return 'd2d4';
          },
        );
        stockfishEngines.add(engine);
        return engine;
      },
    );
    final controller = container.read(gameControllerProvider.notifier);
    await controller.startVsAi(humanSide: Side.white, levelRating: 1100);

    await expectLater(controller.getHint(), throwsA(isA<StateError>()));
    expect(lateReply.isCompleted, isFalse);
    expect(maiaEngines.first.disposeCount, 1);
    expect(stockfishEngines.first.disposeCount, 1);
    lateReply.completeError(StateError('falha Maia atrasada'));
    await Future<void>.delayed(Duration.zero);

    final recovered = await controller.getHint();
    expect(recovered.maiaSan, 'e4');
    expect(recovered.stockfishSan, 'd4');
    expect(maiaEngines, hasLength(2));
    expect(stockfishEngines, hasLength(2));
  });

  test('lance Maia ilegal falha sem esperar um Stockfish preso', () async {
    final stockfishReply = Completer<String>();
    final maia = FakeLc0Engine(onMove: (_, _) async => 'e2e5');
    final stockfish = FakeStockfishEngine(
      onMove: (_, _) => stockfishReply.future,
    );
    final container = _container(
      maiaFactory: () => maia,
      stockfishFactory: () => stockfish,
    );
    final controller = container.read(gameControllerProvider.notifier);
    await controller.startVsAi(humanSide: Side.white, levelRating: 1100);

    await expectLater(controller.getHint(), throwsA(isA<StateError>()));
    expect(stockfishReply.isCompleted, isFalse);
    expect(maia.disposeCount, 1);
    expect(stockfish.disposeCount, 1);
    stockfishReply.complete('d2d4');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
  });

  test(
    'cancelar ambas as buscas ignora erros tardios e permite nova dica',
    () async {
      final maiaStarted = Completer<void>();
      final stockfishStarted = Completer<void>();
      final maiaReply = Completer<String>();
      final stockfishReply = Completer<String>();
      final maiaEngines = <FakeLc0Engine>[];
      final stockfishEngines = <FakeStockfishEngine>[];
      final container = _container(
        maiaFactory: () {
          final first = maiaEngines.isEmpty;
          final engine = FakeLc0Engine(
            onMove: (_, _) {
              if (!first) return Future.value('d2d4');
              maiaStarted.complete();
              return maiaReply.future;
            },
          );
          maiaEngines.add(engine);
          return engine;
        },
        stockfishFactory: () {
          final first = stockfishEngines.isEmpty;
          final engine = FakeStockfishEngine(
            onMove: (_, _) {
              if (!first) return Future.value('g1f3');
              stockfishStarted.complete();
              return stockfishReply.future;
            },
          );
          stockfishEngines.add(engine);
          return engine;
        },
      );
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 1100);
      final pending = controller.getHint();
      final cancelled = expectLater(
        pending,
        throwsA(isA<HintCancelledException>()),
      );
      await Future.wait([maiaStarted.future, stockfishStarted.future]);
      await controller.cancelHint();
      await cancelled;
      expect(maiaEngines.first.disposeCount, 1);
      expect(stockfishEngines.first.disposeCount, 1);
      maiaReply.completeError(StateError('Maia cancelado'));
      stockfishReply.completeError(StateError('Stockfish cancelado'));
      await Future<void>.delayed(Duration.zero);

      final recovered = await controller.getHint();
      expect(recovered.maiaSan, 'd4');
      expect(recovered.stockfishSan, 'Nf3');
      expect(container.read(gameControllerProvider).uciHistory, isEmpty);
      expect(container.read(gameControllerProvider).hintThinking, isFalse);
    },
  );
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
