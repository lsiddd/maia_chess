import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';
import 'package:maia_chess/features/review/presentation/game_review_screen.dart';

import 'game_controller_test.dart'
    show FakeGameRepository, FakeMaiaEngine, FakeStockfishEngine;

void main() {
  for (final pending in [false, true]) {
    testWidgets(
      'leaving ${pending ? 'an unfinished' : 'a completed'} library review releases Stockfish',
      (tester) async {
        final gate = pending ? Completer<void>() : null;
        final engines = <_ReviewEngine>[];
        final maia = FakeMaiaEngine(onMove: (_, _) async => 'e7e5');
        final container = ProviderContainer(
          overrides: [
            gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
            stockfishEngineFactoryProvider.overrideWithValue(() {
              final engine = _ReviewEngine(
                engines.isEmpty ? gate?.future : null,
              );
              engines.add(engine);
              return engine;
            }),
            maiaEngineFactoryProvider.overrideWithValue(() => maia),
            maiaModelResolverProvider.overrideWithValue(
              () async => 'test.onnx',
            ),
            stockfishWarmupEnabledProvider.overrideWithValue(false),
          ],
        );
        final controller = container.read(gameControllerProvider.notifier);
        addTearDown(() {
          if (gate != null && !gate.isCompleted) gate.complete();
          container.dispose();
        });
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100);
        final before = container.read(gameControllerProvider);
        var opened = 0;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      final game = const PgnService().parseImport(
                        pgn: '1. e4 e5 1/2-1/2',
                        id: 'library-${opened++}',
                        importedAtUtc: DateTime.utc(2026),
                      );
                      unawaited(
                        Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => GameReviewScreen(
                              game: game,
                              replayed: const GameReplayer().replay(game),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Review game'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review game'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(engines.single.searches, pending ? 1 : 3);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(engines.single.disposeCount, 1);
        expect(engines.single.isReady, isFalse);
        expect(container.read(gameControllerProvider), same(before));
        expect(maia.disposeCount, 0);

        gate?.complete();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review game'));
        await tester.pumpAndSettle();
        expect(engines, hasLength(2));
        expect(engines.last.searches, 3);
        expect(engines.last.isReady, isTrue);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(engines.last.disposeCount, 1);
        expect(tester.takeException(), isNull);
        await controller.shutdownEngines();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('only the last review owner releases the shared engine', () async {
    final engine = _ReviewEngine(null);
    final container = ProviderContainer(
      overrides: [
        stockfishEngineFactoryProvider.overrideWithValue(() => engine),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);
    final before = container.read(gameControllerProvider);
    final releaseFirst = controller.acquireStockfishForReview();
    final releaseSecond = controller.acquireStockfishForReview();
    await _search(controller);
    releaseFirst();
    releaseFirst();
    expect(engine.disposeCount, 0);
    releaseSecond();
    expect(engine.disposeCount, 1);
    expect(container.read(gameControllerProvider), same(before));
    await controller.shutdownEngines();
  });

  test('an old review cannot release a newer game engine', () async {
    final engines = <_ReviewEngine>[];
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        stockfishEngineFactoryProvider.overrideWithValue(() {
          final engine = _ReviewEngine(null);
          engines.add(engine);
          return engine;
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);
    final releaseOld = controller.acquireStockfishForReview();
    await _search(controller);
    await controller.startTwoPlayers();
    final releaseNew = controller.acquireStockfishForReview();
    await _search(controller);
    expect(engines, hasLength(2));
    expect(engines.first.disposeCount, 1);
    releaseOld();
    expect(engines.last.disposeCount, 0);
    releaseNew();
    expect(engines.last.disposeCount, 1);
    await controller.shutdownEngines();
  });
}

Future<List<StockfishLine>> _search(GameController controller) =>
    controller.searchStockfishForReview(
      fen: Chess.initial.fen,
      initialFen: Chess.initial.fen,
      moves: const [],
      count: 1,
      movetimeMs: 100,
      ensureActive: () {},
    );

class _ReviewEngine extends FakeStockfishEngine {
  _ReviewEngine(this.gate) : super(onMove: (_, _) async => 'e2e4');
  final Future<void>? gate;
  int searches = 0;

  @override
  Future<List<StockfishLine>> getTopMoves(
    String fen, {
    int count = 3,
    int movetimeMs = 1000,
  }) async {
    searches++;
    await gate;
    final position = Chess.fromSetup(Setup.parseFen(fen));
    final move = [
      'd2d4',
      'g1f3',
      'e7e5',
      'b8c6',
    ].firstWhere((uci) => position.isLegal(NormalMove.fromUci(uci)));
    return [
      StockfishLine(rank: 1, depth: 10, moves: [move], centipawns: 0),
    ];
  }
}
