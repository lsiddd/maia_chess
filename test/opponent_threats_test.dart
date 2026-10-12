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
    expectSync(count, 3);
    expectSync(movetimeMs, 1000);
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
          () => FakeLc0Engine(
            onMove: (fen, _) async =>
                fen.split(' ')[1] == 'b' ? 'e7e5' : 'e2e4',
          ),
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

  test('single search, position cache, and unrated game', () async {
    final engine = MultiPvEngine();
    final container = containerFor(() => engine);
    final controller = container.read(gameControllerProvider.notifier);
    await controller.startTwoPlayers();
    final first = controller.getOpponentThreats();
    expect(identical(first, controller.getOpponentThreats()), isTrue);
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
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
    'analysis allows moves and discards the response for the old position',
    () async {
      final started = Completer<void>();
      final reply = Completer<List<StockfishLine>>();
      final engine = MultiPvEngine(
        onAnalysis: (_) {
          started.complete();
          return reply.future;
        },
      );
      final container = containerFor(() => engine);
      final controller = container.read(gameControllerProvider.notifier);
      final pending = controller.getOpponentThreats();
      final stale = expectLater(
        pending,
        throwsA(isA<HintCancelledException>()),
      );
      await started.future;
      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      expect(container.read(gameControllerProvider).uciHistory, ['e2e4']);
      reply.complete([]);
      await stale;
      await controller.undo();
      expect(container.read(gameControllerProvider).position, Chess.initial);
      expect(engine.disposeCount, 0);
    },
  );

  test(
    'hint waits for the opponent-plan search without overlapping Stockfish searches',
    () async {
      final started = Completer<void>();
      final reply = Completer<List<StockfishLine>>();
      final engine = MultiPvEngine(
        onAnalysis: (_) {
          started.complete();
          return reply.future;
        },
      );
      final container = containerFor(() => engine);
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 1100);
      final threat = controller.getOpponentThreats();
      final cancelled = expectLater(
        threat,
        throwsA(isA<HintCancelledException>()),
      );
      await started.future;
      final hint = controller.getHint();
      await cancelled;
      await Future<void>.delayed(Duration.zero);
      expect(engine.requestedFens, isEmpty);
      reply.complete([]);
      expect((await hint).stockfishSan, 'e4');
      expect(engine.requestedFens, hasLength(1));
      expect(engine.disposeCount, 0);
    },
  );

  test('closing a completed hint does not cancel background arrows', () async {
    final started = Completer<void>();
    final reply = Completer<List<StockfishLine>>();
    final engine = MultiPvEngine(
      onAnalysis: (_) {
        started.complete();
        return reply.future;
      },
    );
    final container = containerFor(() => engine);
    final controller = container.read(gameControllerProvider.notifier);
    final pending = controller.getOpponentThreats();
    await started.future;
    await controller.cancelHint();
    reply.complete([
      StockfishLine(rank: 1, depth: 10, moves: ['e7e5'], centipawns: 0),
    ]);
    expect((await pending).threats.single.san, 'e5');
    expect(engine.disposeCount, 0);
  });

  test('restart cancels analysis and discards delayed responses', () async {
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

  test('timeout releases the game and allows retry', () async {
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

  test(
    'cancel and reopen reuse the engine after the previous search',
    () async {
      final started = Completer<void>();
      final reply = Completer<List<StockfishLine>>();
      var searches = 0;
      final engine = MultiPvEngine(
        onAnalysis: (_) async {
          if (++searches == 1) {
            started.complete();
            return reply.future;
          }
          return [
            StockfishLine(rank: 1, depth: 8, moves: ['e7e5'], centipawns: 0),
          ];
        },
      );
      final container = containerFor(() => engine);
      final controller = container.read(gameControllerProvider.notifier);
      final first = controller.getOpponentThreats();
      final cancelled = expectLater(
        first,
        throwsA(isA<HintCancelledException>()),
      );
      await started.future;
      controller.cancelOpponentThreats();
      await cancelled;
      final second = controller.getOpponentThreats();
      await Future<void>.delayed(Duration.zero);
      expect(engine.analyses, hasLength(1));
      reply.complete([]);
      expect((await second).threats.single.san, 'e5');
      expect(engine.disposeCount, 0);
      expect(engine.analyses, hasLength(2));
    },
  );

  test(
    'changing position invalidates cache and analyses the other side',
    () async {
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
    },
  );

  test(
    'an illegal variation fails and allows retry with a new engine',
    () async {
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
    },
  );

  test('check neither starts a search nor changes eligibility', () async {
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

  test(
    'a hypothetical position without moves does not start Stockfish',
    () async {
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
    },
  );
}
