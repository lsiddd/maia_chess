import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/tactics/application/live_threat_controller.dart';

import 'game_controller_test.dart' show FakeGameRepository;
import 'opponent_threats_test.dart' show MultiPvEngine, PositionedController;

void main() {
  ProviderContainer containerFor(MultiPvEngine engine, {String? fen}) {
    final container = ProviderContainer(
      overrides: [
        if (fen != null)
          gameControllerProvider.overrideWith(() => PositionedController(fen)),
        stockfishEngineFactoryProvider.overrideWithValue(() => engine),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      ],
    );
    final subscription = container.listen(
      liveThreatControllerProvider,
      (_, _) {},
    );
    addTearDown(() async {
      subscription.close();
      await container.read(gameControllerProvider.notifier).shutdownEngines();
      container.dispose();
    });
    return container;
  }

  test('mudanças rápidas calculam só a última posição da fila', () async {
    final started = Completer<void>();
    final reply = Completer<List<StockfishLine>>();
    var calls = 0;
    final engine = MultiPvEngine(
      onAnalysis: (fen) {
        if (++calls == 1) {
          started.complete();
          return reply.future;
        }
        return Future.value(lines(fen));
      },
    );
    final container = containerFor(engine);
    final live = container.read(liveThreatControllerProvider.notifier);
    final game = container.read(gameControllerProvider.notifier);
    live.setEnabled(true);
    await started.future;
    for (final move in [
      (Square.e2, Square.e4),
      (Square.e7, Square.e5),
      (Square.g1, Square.f3),
    ]) {
      await game.attemptDragMove(
        move.$1,
        move.$2,
        onPromotion: () async => null,
      );
      await flush();
    }
    expect(engine.analyses, hasLength(1));
    expect(container.read(liveThreatControllerProvider).result, isNull);
    reply.complete(lines(engine.analyses.first));
    await flush();
    expect(engine.analyses, hasLength(2));
    expect(
      container.read(liveThreatControllerProvider).result!.position.board,
      container.read(gameControllerProvider).position.board,
    );
    expect(engine.disposeCount, 0);
    live.setEnabled(false);
    await game.undo();
    await flush();
    expect(engine.analyses, hasLength(2));
    expect(container.read(liveThreatControllerProvider).result, isNull);
  });

  test(
    'suspensão descarta resposta tardia e retoma na posição atual',
    () async {
      final started = Completer<void>();
      final reply = Completer<List<StockfishLine>>();
      var calls = 0;
      final engine = MultiPvEngine(
        onAnalysis: (fen) {
          if (++calls == 1) {
            started.complete();
            return reply.future;
          }
          return Future.value(lines(fen));
        },
      );
      final container = containerFor(engine);
      final live = container.read(liveThreatControllerProvider.notifier);
      live.setEnabled(true);
      await started.future;
      live.setPaused(true);
      reply.complete(lines(engine.analyses.first));
      await flush();
      expect(container.read(liveThreatControllerProvider).paused, isTrue);
      expect(container.read(liveThreatControllerProvider).result, isNull);
      expect(engine.analyses, hasLength(1));
      live.setPaused(false);
      await flush();
      expect(
        container.read(liveThreatControllerProvider).result!.threats,
        hasLength(3),
      );
      expect(engine.analyses, hasLength(2));
    },
  );

  test('reinício desativa as setas e invalida respostas anteriores', () async {
    final engine = MultiPvEngine();
    final container = containerFor(engine);
    final game = container.read(gameControllerProvider.notifier);
    await game.startTwoPlayers();
    container.read(liveThreatControllerProvider.notifier).setEnabled(true);
    await flush();
    expect(container.read(liveThreatControllerProvider).result, isNotNull);
    await game.reset();
    await flush();
    expect(container.read(liveThreatControllerProvider).enabled, isFalse);
    expect(container.read(liveThreatControllerProvider).result, isNull);
    expect(engine.analyses, hasLength(1));
  });

  test('xeque pausa e sair do xeque atualiza automaticamente', () async {
    final engine = MultiPvEngine(onAnalysis: (fen) async => lines(fen));
    final container = containerFor(
      engine,
      fen: '4r1k1/8/8/8/8/8/8/4K3 w - - 0 1',
    );
    container.read(liveThreatControllerProvider.notifier).setEnabled(true);
    await flush();
    expect(container.read(liveThreatControllerProvider).loading, isFalse);
    expect(engine.analyses, isEmpty);
    await container
        .read(gameControllerProvider.notifier)
        .attemptDragMove(Square.e1, Square.d1, onPromotion: () async => null);
    await flush();
    expect(container.read(liveThreatControllerProvider).result, isNotNull);
    expect(engine.analyses, hasLength(1));
  });
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

List<StockfishLine> lines(String fen) {
  final position = Chess.fromSetup(Setup.parseFen(fen));
  final moves = [
    for (final entry in position.legalMoves.entries)
      for (final to in entry.value.squares)
        NormalMove(from: entry.key, to: to).uci,
  ].take(3).toList();
  return [
    for (var i = 0; i < moves.length; i++)
      StockfishLine(rank: i + 1, depth: 10, moves: [moves[i]], centipawns: 0),
  ];
}
