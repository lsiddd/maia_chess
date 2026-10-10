import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'package:maia_chess/features/tactics/presentation/threat_dialog.dart';
import 'package:maia_chess/features/tactics/domain/tactical_analysis.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';

import 'game_controller_test.dart' show FakeGameRepository;
import 'opponent_threats_test.dart' show PositionedController, MultiPvEngine;

void main() {
  testWidgets('botão destaca os dois lados, acompanha lance e orientação', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => PositionedController('4k3/8/2p5/3p4/4P3/5P2/8/4K3 w - - 0 1'),
        ),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(450, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attacked-piece-indicator')), findsNothing);
    await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attacked-piece-indicator')), findsNWidgets(2));
    for (final square in ['e4', 'd5']) {
      expect(
        tester
            .getSemantics(find.byKey(ValueKey('board-semantics-$square')))
            .value,
        contains('Peça atacada'),
      );
    }
    expect(find.byKey(const Key('attacked-pieces-legend')), findsOneWidget);
    expect(container.read(gameControllerProvider).evaluated, isFalse);
    await tester.tap(find.byTooltip('Inverter tabuleiro'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attacked-piece-indicator')), findsNWidgets(2));
    await container
        .read(gameControllerProvider.notifier)
        .attemptDragMove(Square.e4, Square.d5, onPromotion: () async => null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attacked-piece-indicator')), findsNWidgets(2));
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('board-semantics-e4')))
          .value,
      isNot(contains('Peça atacada')),
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('board-semantics-c6')))
          .value,
      contains('Peça atacada'),
    );
    await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attacked-piece-indicator')), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('botão mostra três alternativas, avaliação e fecha sem erro', (
    tester,
  ) async {
    final engine = MultiPvEngine();
    final container = ProviderContainer(
      overrides: [
        stockfishEngineFactoryProvider.overrideWithValue(() => engine),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      ],
    );
    addTearDown(() async {
      await container.read(gameControllerProvider.notifier).shutdownEngines();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('d5'), findsOneWidget);
    expect(find.text('Nf6'), findsOneWidget);
    expect(find.text('e7 → e5'), findsOneWidget);
    expect(find.textContaining('perspectiva do adversário'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diálogo cabe em tela pequena com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = ThreatResult.fromLines(
      opponentThreatPosition(Chess.initial),
      [
        StockfishLine(rank: 1, depth: 12, moves: ['e7e5'], centipawns: 30),
        StockfishLine(rank: 2, depth: 12, moves: ['d7d5'], centipawns: -15),
        StockfishLine(rank: 3, depth: 12, moves: ['g8f6'], mate: -3),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                showThreatDialog(
                  context,
                  Future.value(result),
                  onClosed: () async {},
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
  });

  testWidgets('ajudas ativas cabem em tela estreita com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
    await tester.pumpAndSettle();
  });

  testWidgets('erro da análise permite fechar e tentar novamente', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                showThreatDialog(
                  context,
                  Future.error(StateError('motor indisponível')),
                  onClosed: () async {
                    closed = true;
                  },
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível concluir'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
