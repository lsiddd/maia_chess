import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeLc0Engine;

void main() {
  testWidgets('Try again preserves the game and retries the AI move', (
    tester,
  ) async {
    final repository = FakeGameRepository();
    final engines = <FakeLc0Engine>[];
    final answer = Completer<String>();
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repository),
        gameIdFactoryProvider.overrideWithValue(() => 'retry-game'),
        maiaWeightsResolverProvider.overrideWithValue(
          (level) async => level.weightsAsset,
        ),
        lc0EngineFactoryProvider.overrideWithValue(() {
          final attempt = engines.length;
          final engine = FakeLc0Engine(
            onMove: (_, _) async {
              if (attempt < 2) throw StateError('search failed');
              return answer.future;
            },
          );
          engines.add(engine);
          return engine;
        }),
      ],
    );
    final controller = container.read(gameControllerProvider.notifier);
    addTearDown(container.dispose);
    await controller.startVsAi(
      humanSide: Side.white,
      levelRating: 1100,
      campaignMode: true,
    );
    await controller.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    final before = container.read(gameControllerProvider);
    expect(before.engineError, contains('search failed'));

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Another failure must preserve the position and allow retry.
    await tester.tap(find.byTooltip('Try again'));
    await tester.pumpAndSettle();
    final failedAgain = container.read(gameControllerProvider);
    expect(failedAgain.position.fen, before.position.fen);
    expect(failedAgain.uciHistory, ['e2e4']);
    expect(failedAgain.engineError, contains('search failed'));
    expect(engines, hasLength(2));
    expect(engines.take(2).every((engine) => engine.disposeCount == 1), isTrue);

    // Two taps before rebuilding must not start two searches.
    await tester.tap(find.byTooltip('Try again'));
    await tester.tap(find.byTooltip('Try again'));
    await tester.pump();
    expect(container.read(gameControllerProvider).aiThinking, isTrue);
    expect(find.byTooltip('Try again'), findsNothing);
    expect(find.text('Maia to move'), findsOneWidget);
    expect(engines, hasLength(3));
    expect(engines.last.requestedFens, [before.position.fen]);

    answer.complete('e7e5');
    await tester.pumpAndSettle();
    final after = container.read(gameControllerProvider);
    expect(after.uciHistory, ['e2e4', 'e7e5']);
    expect(after.sanHistory, ['e4', 'e5']);
    expect(after.positionHistory.last.fen, before.position.fen);
    expect(after.gameId, before.gameId);
    expect(after.startedAtUtc, before.startedAtUtc);
    expect(after.campaignMode, before.campaignMode);
    expect(after.levelRating, before.levelRating);
    expect(after.evaluated, before.evaluated);
    expect(after.aiSide, before.aiSide);
    expect(after.engineError, isNull);
    expect(after.aiThinking, isFalse);
    final stored = await repository.getActiveGame();
    expect(stored!.id, before.gameId);
    expect(stored.moves.map((move) => move.uci), ['e2e4', 'e7e5']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.shutdownEngines();
  });
}
