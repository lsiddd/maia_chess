import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'package:maia_chess/features/game/presentation/game_toolbar.dart';
import 'package:maia_chess/features/tactics/presentation/threat_arrows.dart';
import 'package:maia_chess/features/tactics/application/live_threat_controller.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';

import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'support_game_settings.dart';
import 'game_controller_test.dart' show FakeGameRepository;
import 'opponent_threats_test.dart' show PositionedController, MultiPvEngine;

void main() {
  testWidgets('campaign locks tools without changing attack preferences', (
    tester,
  ) async {
    final settings = MemorySettings(
      const StoredAppSettings(showAttackedPieces: true),
    );
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        gameControllerProvider.overrideWith(_CampaignPositionController.new),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await settings.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Undo', 'Hint', 'Attacks', 'Plans']) {
      final button = tester.widget<GameToolButton>(
        find.widgetWithText(GameToolButton, label),
      );
      expect(button.onPressed, isNull, reason: label);
      expect(button.active, label == 'Undo' ? isNull : isFalse, reason: label);
    }
    final plans = container.read(liveThreatControllerProvider.notifier);
    plans.setEnabled(true);
    await tester.pumpAndSettle();
    expect(container.read(liveThreatControllerProvider).enabled, isFalse);
    expect(find.byKey(const Key('attacked-piece-indicator')), findsNothing);
    expect(find.byKey(const Key('opponent-threat-arrows')), findsNothing);
    expect(container.read(gameControllerProvider).evaluated, isTrue);
    expect(settings.value.showAttackedPieces, isTrue);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Attacks:'), findsNothing);
    expect(find.text('Tool help'), findsNothing);
    expect(find.text('Rotate board'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'preference filters own pieces and distinguishes defence from attack',
    (tester) async {
      final settings = MemorySettings(
        const StoredAppSettings(
          showAttackedPieces: true,
          ownAttackedPiecesOnly: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          gameControllerProvider.overrideWith(
            () => PositionedController('4k3/8/2p5/3p4/4P3/8/8/4K3 w - - 0 1'),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await settings.close();
      });
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attacked-piece-indicator')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('board-semantics-e4'))).value,
        contains('without geometric defence'),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('board-semantics-d5'))).value,
        isNot(contains('Attacked piece')),
      );
      await settings.save(
        settings.value.copyWith(ownAttackedPiecesOnly: false),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('attacked-piece-indicator')),
        findsNWidgets(2),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('board-semantics-d5'))).value,
        contains('defended'),
      );
      expect(container.read(gameControllerProvider).evaluated, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'button highlights both sides and follows moves and orientation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(MemorySettings()),
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
      await tester.ensureVisible(
        find.byKey(const Key('toggle-attacked-pieces')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('attacked-piece-indicator')),
        findsNWidgets(2),
      );
      for (final square in ['e4', 'd5']) {
        expect(
          tester
              .getSemantics(find.byKey(ValueKey('board-semantics-$square')))
              .value,
          contains('Attacked piece'),
        );
      }
      expect(find.byKey(const Key('attacked-pieces-legend')), findsNothing);
      expect(container.read(gameControllerProvider).evaluated, isFalse);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate board'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('attacked-piece-indicator')),
        findsNWidgets(2),
      );
      await container
          .read(gameControllerProvider.notifier)
          .attemptDragMove(Square.e4, Square.d5, onPromotion: () async => null);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('attacked-piece-indicator')),
        findsNWidgets(2),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('board-semantics-e4')))
            .value,
        isNot(contains('Attacked piece')),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('board-semantics-c6')))
            .value,
        contains('Attacked piece'),
      );
      await tester.ensureVisible(
        find.byKey(const Key('toggle-attacked-pieces')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attacked-piece-indicator')), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'arrows update without blocking moves and follow rotation and undo',
    (tester) async {
      final secondReply = Completer<List<StockfishLine>>();
      var searches = 0;
      final engine = MultiPvEngine(
        onAnalysis: (fen) async {
          if (++searches == 2) return secondReply.future;
          return legalLines(fen);
        },
      );
      final container = threatContainer(engine);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final boardRect = tester.getRect(find.byKey(const Key('chess-board')));
      await tester.ensureVisible(
        find.byKey(const Key('show-opponent-threats')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('show-opponent-threats')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.getRect(find.byKey(const Key('chess-board'))), boardRect);
      final firstPlan = painter(tester).threats.single;
      await tester.tap(find.byKey(const Key('next-opponent-plan')));
      await tester.pumpAndSettle();
      expect(painter(tester).threats.single, isNot(same(firstPlan)));
      expect(painter(tester).threats, hasLength(1));
      expect(tester.getRect(find.byKey(const Key('chess-board'))), boardRect);
      expect(find.byKey(const Key('opponent-threat-arrows')), findsOneWidget);
      expect(painter(tester).threats, hasLength(1));
      expect(container.read(gameControllerProvider).hintThinking, isFalse);
      expect(container.read(gameControllerProvider).evaluated, isFalse);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate board'));
      await tester.pumpAndSettle();
      expect(painter(tester).orientation, Side.black);
      expect(searches, 1);

      // Taps pass through the arrow layer; selection does not start another
      // search.
      await tester.tap(find.byKey(const ValueKey('board-semantics-e2')));
      await tester.pumpAndSettle();
      expect(searches, 1);
      await tester.tap(find.byKey(const ValueKey('board-semantics-e4')));
      await tester.pump();
      expect(find.byKey(const Key('opponent-threat-arrows')), findsNothing);
      expect(container.read(gameControllerProvider).uciHistory, ['e2e4']);
      await tester.pump(const Duration(milliseconds: 300));
      expect(searches, 2);

      // Continue playing while Stockfish analyses the previous position.
      final game = container.read(gameControllerProvider.notifier);
      await game.attemptDragMove(
        Square.e7,
        Square.e5,
        onPromotion: () async => null,
      );
      await tester.pump();
      expect(searches, 2);
      secondReply.complete(legalLines(engine.analyses[1]));
      await tester.pumpAndSettle();
      expect(searches, 3);
      expect(engine.analyses.last, contains(' b '));
      final result = container.read(liveThreatControllerProvider).result!;
      expect(
        result.position.board,
        container.read(gameControllerProvider).position.board,
      );
      expect(painter(tester).threats.single, same(result.threats.first));
      await game.undo();
      await tester.pumpAndSettle();
      expect(engine.analyses.last, contains(' w '));
      expect(engine.disposeCount, 0);
      await tester.ensureVisible(
        find.byKey(const Key('show-opponent-threats')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('show-opponent-threats')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opponent-threat-arrows')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await game.shutdownEngines();
    },
  );

  test('arrow geometry reverses origin and destination with the board', () {
    const white = ThreatArrowPainter(threats: [], orientation: Side.white);
    const black = ThreatArrowPainter(threats: [], orientation: Side.black);
    const size = Size.square(400);
    expect(white.squareCenter(Square.e7, size), const Offset(225, 75));
    expect(white.squareCenter(Square.e5, size), const Offset(225, 175));
    expect(black.squareCenter(Square.e7, size), const Offset(175, 325));
    expect(black.squareCenter(Square.e5, size), const Offset(175, 225));
    expect(black.shouldRepaint(white), isTrue);
    expect(white.shouldRepaint(white), isFalse);
  });

  testWidgets('active tools fit a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(MemorySettings()),
        stockfishEngineFactoryProvider.overrideWithValue(MultiPvEngine.new),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
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
    await tester.ensureVisible(find.byKey(const Key('toggle-attacked-pieces')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opponent-threat-legend')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await container.read(gameControllerProvider.notifier).shutdownEngines();
  });

  testWidgets('arrow failure allows retry without blocking the game', (
    tester,
  ) async {
    var attempts = 0;
    final engine = MultiPvEngine(
      onAnalysis: (fen) async {
        if (++attempts == 1) throw StateError('engine unavailable');
        return legalLines(fen);
      },
    );
    final container = threatContainer(engine);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Analysis unavailable'), findsOneWidget);
    expect(container.read(gameControllerProvider).hintThinking, isFalse);
    await tester.ensureVisible(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-opponent-threats')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opponent-threat-arrows')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await container.read(gameControllerProvider.notifier).shutdownEngines();
  });
}

class _CampaignPositionController extends GameController {
  @override
  GameState build() {
    const e4 = NormalMove(from: Square.e2, to: Square.e4);
    const d5 = NormalMove(from: Square.d7, to: Square.d5);
    final afterE4 = Chess.initial.play(e4) as Chess;
    return super.build().copyWith(
      position: afterE4.play(d5) as Chess,
      positionHistory: [Chess.initial, afterE4],
      sanHistory: const ['e4', 'd5'],
      uciHistory: [e4.uci, d5.uci],
      moveActorHistory: const [GameMoveActor.player, GameMoveActor.maia],
      moveTimeHistoryUtc: [DateTime.utc(2026), DateTime.utc(2026)],
      aiSide: Side.black,
      levelRating: 1100,
      campaignMode: true,
    );
  }
}

ThreatArrowPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const Key('opponent-threat-arrows')),
            )
            .painter!
        as ThreatArrowPainter;

ProviderContainer threatContainer(MultiPvEngine engine) {
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(MemorySettings()),
      stockfishEngineFactoryProvider.overrideWithValue(() => engine),
      stockfishWarmupEnabledProvider.overrideWithValue(false),
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

List<StockfishLine> legalLines(String fen) {
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
        depth: 10,
        moves: [moves[i]],
        centipawns: 30 - i * 10,
      ),
  ];
}
