import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';

import 'game_controller_test.dart'
    show FakeGameRepository, FakeStockfishEngine, FakeLc0Engine;

class MultiPvEngine extends FakeStockfishEngine {
  MultiPvEngine({this.onAnalysis}) : super(onMove: (_, _) async => 'e2e4');
  final Future<List<StockfishLine>> Function(String)? onAnalysis;
  final analyses = <String>[];

  @override
  Future<List<StockfishLine>> getTopMoves(
    String fen, {
    int count = 3,
    int movetimeMs = 1000,
  }) async {
    expect(count, 3);
    expect(movetimeMs, 1000);
    analyses.add(fen);
    if (onAnalysis != null) return onAnalysis!(fen);
    final moves = fen.split(' ')[1] == 'b'
        ? ['e7e5', 'd7d5', 'g8f6']
        : ['e2e4', 'd2d4', 'g1f3'];
    return [
      for (var i = 0; i < 3; i++)
        StockfishLine(
          rank: i + 1,
          depth: 10,
          moves: [moves[i]],
          centipawns: 30 - i * 10,
        ),
    ];
  }
}

class SlowDisposalEngine extends MultiPvEngine {
  SlowDisposalEngine(this.released, {super.onAnalysis});
  final Future<void> released;

  @override
  Future<void> dispose() async {
    await released;
    await super.dispose();
  }
}

class PositionedController extends GameController {
  PositionedController(this.fen);
  final String fen;
  @override
  GameState build() =>
      super.build().copyWith(position: Chess.fromSetup(Setup.parseFen(fen)));
}

void main() {
  ProviderContainer containerFor(
    MultiPvEngine Function() factory, {
    String? fen,
    Duration timeout = const Duration(seconds: 2),
  }) {
    final container = ProviderContainer(
      overrides: [
        if (fen != null)
          gameControllerProvider.overrideWith(() => PositionedController(fen)),
        stockfishEngineFactoryProvider.overrideWithValue(factory),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
        lc0EngineFactoryProvider.overrideWithValue(
          () => FakeLc0Engine(onMove: (_, _) async => 'e7e5'),
        ),
        maiaWeightsResolverProvider.overrideWithValue(
          (level) async => level.weightsAsset,
        ),
        hintTotalTimeoutProvider.overrideWithValue(timeout),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      ],
    );
    addTearDown(() async {
      await container.read(gameControllerProvider.notifier).shutdownEngines();
      container.dispose();
    });
    return container;
  }

  test('busca única, cache por posição e partida não avaliada', () async {
    final engine = MultiPvEngine();
    final container = containerFor(() => engine);
    final controller = container.read(gameControllerProvider.notifier);
    await controller.startTwoPlayers();
    final first = controller.getOpponentThreats();
    expect(identical(first, controller.getOpponentThreats()), isTrue);
    expect(container.read(gameControllerProvider).hintThinking, isTrue);
    final result = await first;
    expect(result.threats.map((t) => t.san), ['e5', 'd5', 'Nf6']);
    expect(container.read(gameControllerProvider).evaluated, isFalse);
    expect(
      (await container.read(gameRepositoryProvider).getActiveGame())!.evaluated,
      isFalse,
    );
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
    expect(identical(result, await controller.getOpponentThreats()), isTrue);
    expect(engine.analyses, hasLength(1));
    expect(container.read(gameControllerProvider).position, Chess.initial);
    expect(container.read(gameControllerProvider).uciHistory, isEmpty);

    await controller.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    // The new hypothetical side is white; e2e4 is no longer legal, so use
    // the restart to verify generation invalidation independently of FEN.
    await controller.reset();
    await controller.getOpponentThreats();
    expect(engine.analyses, hasLength(2));
  });

  test(
    'bloqueia lances, undo e dica enquanto analisa; cancelamento recupera',
    () async {
      final started = Completer<void>();
      final late = Completer<List<StockfishLine>>();
      final engines = <MultiPvEngine>[];
      final container = containerFor(() {
        final first = engines.isEmpty;
        final engine = MultiPvEngine(
          onAnalysis: first
              ? (_) {
                  started.complete();
                  return late.future;
                }
              : null,
        );
        engines.add(engine);
        return engine;
      });
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 1100);
      final pending = controller.getOpponentThreats();
      final cancelled = expectLater(
        pending,
        throwsA(isA<HintCancelledException>()),
      );
      await started.future;
      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      await controller.undo();
      expect(container.read(gameControllerProvider).position, Chess.initial);
      await expectLater(controller.getHint(), throwsStateError);
      await controller.cancelHint();
      await cancelled;
      late.completeError(StateError('resposta tardia'));
      await Future<void>.delayed(Duration.zero);
      expect((await controller.getOpponentThreats()).threats, hasLength(3));
      expect(engines.first.disposeCount, 1);
      expect(container.read(gameControllerProvider).hintThinking, isFalse);
    },
  );

  test('reiniciar cancela a análise e descarta respostas tardias', () async {
    final started = Completer<void>();
    final late = Completer<List<StockfishLine>>();
    final engine = MultiPvEngine(
      onAnalysis: (_) {
        started.complete();
        return late.future;
      },
    );
    final container = containerFor(() => engine);
    final controller = container.read(gameControllerProvider.notifier);
    final pending = controller.getOpponentThreats();
    final cancelled = expectLater(
      pending,
      throwsA(isA<HintCancelledException>()),
    );
    await started.future;
    await controller.reset();
    await cancelled;
    late.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(gameControllerProvider).evaluated, isTrue);
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
  });

  test('timeout libera a partida e permite nova tentativa', () async {
    final late = Completer<List<StockfishLine>>();
    final engine = MultiPvEngine(onAnalysis: (_) => late.future);
    final container = containerFor(
      () => engine,
      timeout: const Duration(milliseconds: 20),
    );
    final controller = container.read(gameControllerProvider.notifier);
    await expectLater(
      controller.getOpponentThreats(),
      throwsA(isA<TimeoutException>()),
    );
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
    expect(engine.disposeCount, 1);
    late.complete([]);
  });

  test('reabrir análise aguarda liberação do singleton nativo', () async {
    final started = Completer<void>();
    final reply = Completer<List<StockfishLine>>();
    final released = Completer<void>();
    final engines = <MultiPvEngine>[];
    final container = containerFor(() {
      final engine = engines.isEmpty
          ? SlowDisposalEngine(
              released.future,
              onAnalysis: (_) {
                started.complete();
                return reply.future;
              },
            )
          : MultiPvEngine();
      engines.add(engine);
      return engine;
    });
    final controller = container.read(gameControllerProvider.notifier);
    final first = controller.getOpponentThreats();
    final cancelled = expectLater(
      first,
      throwsA(isA<HintCancelledException>()),
    );
    await started.future;
    final closing = controller.cancelHint();
    await cancelled;
    final second = controller.getOpponentThreats();
    await Future<void>.delayed(Duration.zero);
    expect(engines, hasLength(1));
    released.complete();
    await closing;
    expect((await second).threats, hasLength(3));
    expect(engines, hasLength(2));
    reply.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
  });

  test('mudar de posição invalida cache e consulta o outro lado', () async {
    final engine = MultiPvEngine(
      onAnalysis: (fen) async {
        final position = Chess.fromSetup(Setup.parseFen(fen));
        final moves = [
          for (final entry in position.legalMoves.entries)
            for (final to in entry.value.squares)
              NormalMove(from: entry.key, to: to).uci,
        ].take(3).toList();
        return [
          for (var i = 0; i < moves.length; i++)
            StockfishLine(
              rank: i + 1,
              depth: 8,
              moves: [moves[i]],
              centipawns: 0,
            ),
        ];
      },
    );
    final container = containerFor(() => engine);
    final controller = container.read(gameControllerProvider.notifier);
    expect((await controller.getOpponentThreats()).position.turn, Side.black);
    await controller.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    final result = await controller.getOpponentThreats();
    expect(result.position.turn, Side.white);
    expect(engine.analyses.toSet(), hasLength(2));
    expect(
      result.position.board,
      container.read(gameControllerProvider).position.board,
    );
  });

  test('variante ilegal falha e permite repetir com um motor novo', () async {
    var creations = 0;
    final container = containerFor(() {
      creations++;
      return MultiPvEngine(
        onAnalysis: creations == 1
            ? (_) async => [
                StockfishLine(
                  rank: 1,
                  depth: 8,
                  moves: ['e7e4'],
                  centipawns: 0,
                ),
              ]
            : null,
      );
    });
    final controller = container.read(gameControllerProvider.notifier);
    await expectLater(
      controller.getOpponentThreats(),
      throwsA(isA<PlayException>()),
    );
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
    expect((await controller.getOpponentThreats()).threats, hasLength(3));
    expect(creations, 2);
  });

  test('xeque não inicia busca nem altera avaliação', () async {
    final engine = MultiPvEngine();
    final container = containerFor(
      () => engine,
      fen: '4r1k1/8/8/8/8/8/8/4K3 w - - 0 1',
    );
    await expectLater(
      container.read(gameControllerProvider.notifier).getOpponentThreats(),
      throwsStateError,
    );
    expect(engine.analyses, isEmpty);
    expect(container.read(gameControllerProvider).evaluated, isTrue);
  });

  test('posição hipotética sem lances não inicia Stockfish', () async {
    final engine = MultiPvEngine();
    final container = containerFor(
      () => engine,
      fen: '7k/5K2/6Q1/8/8/8/8/8 w - - 0 1',
    );
    final result = await container
        .read(gameControllerProvider.notifier)
        .getOpponentThreats();
    expect(result.threats, isEmpty);
    expect(engine.analyses, isEmpty);
  });
}
