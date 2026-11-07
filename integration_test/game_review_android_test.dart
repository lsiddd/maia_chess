import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';
import 'package:maia_chess/features/review/application/game_review_analyzer.dart';
import 'package:maia_chess/features/review/presentation/review_chart.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completed game opens native review and stays saved on rematch', (
    tester,
  ) async {
    final container = ProviderContainer();
    final controller = container.read(gameControllerProvider.notifier);
    final repository = container.read(gameRepositoryProvider);
    try {
      await controller.startTwoPlayers();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();
      for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        final move = NormalMove.fromUci(uci);
        await controller.attemptDragMove(
          move.from,
          move.to,
          onPromotion: () async => null,
        );
        await tester.pumpAndSettle();
      }
      final finished = container.read(gameControllerProvider);
      expect(finished.isGameOver, isTrue);
      await tester.tap(find.byTooltip('Review game'));
      final graph = find.byType(ReviewChart);
      for (
        var attempt = 0;
        attempt < 120 && graph.evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Game review'), findsOneWidget);
      expect(graph, findsOneWidget);
      expect(container.read(gameControllerProvider).gameId, finished.gameId);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rematch'));
      await tester.pumpAndSettle();
      await controller.flushPersistence();
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).isGameOver, isFalse);
      final saved = await repository.getGame(finished.gameId!);
      expect(saved?.status, StoredGameStatus.completed);
      expect(saved?.moves.map((move) => move.uci), finished.uciHistory);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.shutdownEngines();
      container.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
    'native Stockfish reviews a game and a branch without changing play',
    (tester) async {
      final container = ProviderContainer();
      final controller = container.read(gameControllerProvider.notifier);
      final originalState = container.read(gameControllerProvider);
      final analyzer = container.read(reviewAnalyzerProvider);
      final game = const GameReplayer().replay(
        const PgnService().parseImport(
          pgn: '1. f3 e5 2. g4 Qh4# 0-1',
          id: 'native-review',
          importedAtUtc: DateTime.utc(2026),
        ),
      );

      try {
        final review = await analyzer.analyze(game, request: ReviewRequest());

        expect(review.moves, hasLength(4));
        expect(review.positions[3].lines.first.sans.first, 'Qh4#');
        expect(review.positions[3].evaluation.mate, -1);
        expect(review.positions.last.evaluation.checkmatedSide, Side.white);

        final branch = await analyzer.analyzePosition(
          game,
          0,
          continuation: ['g1f3', 'g8f6', 'b1c3'],
          request: ReviewRequest(),
        );
        final branchPosition = Chess.initial
            .playUnchecked(NormalMove.fromUci('g1f3'))
            .playUnchecked(NormalMove.fromUci('g8f6'))
            .playUnchecked(NormalMove.fromUci('b1c3'));
        expect(branch.lines, isNotEmpty);
        for (final line in branch.lines) {
          expect(branchPosition.isLegal(Move.parse(line.ucis.first)!), isTrue);
        }
        expect(container.read(gameControllerProvider), same(originalState));
      } finally {
        await controller.shutdownEngines();
        container.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
