import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/core/theming/app_theme.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'package:maia_chess/features/hints/application/visual_hint_controller.dart';
import 'package:maia_chess/features/tactics/application/live_threat_controller.dart';
import 'package:maia_chess/features/tactics/presentation/threat_arrows.dart';

/// Fluxo de aceitação em Android com SQLite, Stockfish e Maia reais.
/// Não substitui motores ou repositórios por mocks.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seção 2: ferramentas, histórico, menus, autosave e reinício', (
    tester,
  ) async {
    final container = ProviderContainer();
    final game = container.read(gameControllerProvider.notifier);
    try {
      await container
          .read(settingsRepositoryProvider)
          .save(const StoredAppSettings());
      await game.startTwoPlayers();
      await _showGame(tester, container);
      final board = _rect(tester);
      _expectVisible(tester);
      await tester.tap(find.byKey(const Key('hint-button')));
      await tester.pump();
      expect(_rect(tester), board);
      await _until(
        tester,
        () => !container.read(gameControllerProvider).hintThinking,
      );
      expect(container.read(visualHintProvider), isNotNull);
      expect(find.byKey(const Key('hint-origin-indicator')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(_rect(tester), board);
      await tester.tap(find.byKey(const Key('hint-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hint-origin-indicator')), findsNothing);

      await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
      await _until(
        tester,
        () =>
            container
                .read(appSettingsProvider)
                .valueOrNull
                ?.showAttackedPieces ==
            true,
      );
      expect(_rect(tester), board);
      await tester.tap(find.byKey(const Key('show-opponent-threats')));
      await _until(
        tester,
        () => container.read(liveThreatControllerProvider).result != null,
      );
      final arrows = tester.widget<ThreatArrows>(find.byType(ThreatArrows));
      expect(arrows.threats, hasLength(1));
      await tester.tap(find.byKey(const Key('next-opponent-plan')));
      await tester.pump();
      expect(
        tester.widget<ThreatArrows>(find.byType(ThreatArrows)).threats.single,
        isNot(same(arrows.threats.single)),
      );
      expect(_rect(tester), board);
      await tester.tap(find.byKey(const Key('show-opponent-threats')));
      await tester.pumpAndSettle();
      expect(find.byType(ThreatArrows), findsNothing);

      await _move(tester, 'e2', 'e4');
      await _move(tester, 'e7', 'e5');
      expect(container.read(gameControllerProvider).uciHistory, [
        'e2e4',
        'e7e5',
      ]);
      expect(_rect(tester), board);
      await tester.tap(find.byKey(const Key('move-list-panel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StaticChessBoardWidget>(find.byType(StaticChessBoardWidget))
            .position
            .turn,
        Side.black,
      );
      await tester.tap(find.byTooltip('Fechar histórico'));
      await tester.pumpAndSettle();
      expect(_rect(tester), board);
      await tester.tap(find.byKey(const Key('move-list-panel')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StaticChessBoardWidget>(find.byType(StaticChessBoardWidget))
            .position
            .turn,
        Side.black,
      );
      await tester.tap(find.text('Posição atual'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StaticChessBoardWidget>(find.byType(StaticChessBoardWidget))
            .position
            .fen,
        container.read(gameControllerProvider).position.fen,
      );
      await tester.tap(find.byTooltip('Fechar histórico'));
      await tester.pumpAndSettle();

      await _menu(tester, 'Girar tabuleiro');
      expect(
        tester
            .widget<ChessBoardWidget>(find.byType(ChessBoardWidget))
            .orientation,
        Side.black,
      );
      expect(_rect(tester), board);
      await _menu(tester, 'Ataques: somente minhas peças');
      expect(
        (await container.read(settingsRepositoryProvider).get())
            .ownAttackedPiecesOnly,
        isTrue,
      );
      await _menu(tester, 'Salvar partida');
      await game.flushPersistence();
      final saved = await container
          .read(gameRepositoryProvider)
          .getActiveGame();
      expect(saved!.moves.map((m) => m.uci), ['e2e4', 'e7e5']);
      expect(saved.evaluated, isFalse);
      await _menu(tester, 'Reiniciar');
      expect(find.text('Reiniciar partida?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).uciHistory, hasLength(2));
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).uciHistory, ['e2e4']);
      await _menu(tester, 'Reiniciar');
      await tester.tap(find.widgetWithText(FilledButton, 'Reiniciar'));
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).uciHistory, isEmpty);
      expect(
        (await container.read(settingsRepositoryProvider).get())
            .showAttackedPieces,
        isTrue,
      );
      expect(_rect(tester), board);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await game.shutdownEngines();
      container.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
    'seção 2: Maia real, dica Stockfish, desfazer em pares e retomada',
    (tester) async {
      var container = ProviderContainer();
      try {
        await container
            .read(settingsRepositoryProvider)
            .save(const StoredAppSettings());
        var game = container.read(gameControllerProvider.notifier);
        expect(
          await game.startVsAi(
            humanSide: Side.white,
            levelRating: 1100,
            campaignMode: true,
          ),
          isTrue,
        );
        await _showGame(tester, container);
        final board = _rect(tester);
        await _move(tester, 'e2', 'e4');
        await _until(
          tester,
          () => !container.read(gameControllerProvider).aiThinking,
        );
        expect(container.read(gameControllerProvider).uciHistory, hasLength(2));
        expect(
          container.read(gameControllerProvider).position.turn,
          Side.white,
        );
        await tester.tap(find.byKey(const Key('hint-button')));
        await tester.pump();
        await _until(
          tester,
          () => !container.read(gameControllerProvider).hintThinking,
        );
        expect(container.read(visualHintProvider), isNotNull);
        expect(_rect(tester), board);
        expect(container.read(gameControllerProvider).evaluated, isFalse);
        final fen = container.read(gameControllerProvider).position.fen;
        await game.flushPersistence();
        await tester.pumpWidget(const SizedBox());
        await game.shutdownEngines();
        container.dispose();
        container = ProviderContainer();
        game = container.read(gameControllerProvider.notifier);
        expect(await game.restoreActiveGame(), isTrue);
        expect(container.read(gameControllerProvider).position.fen, fen);
        expect(container.read(gameControllerProvider).evaluated, isFalse);
        expect(container.read(gameControllerProvider).campaignMode, isTrue);
        await _showGame(tester, container);
        await tester.tap(find.text('Desfazer'));
        await tester.pumpAndSettle();
        expect(container.read(gameControllerProvider).uciHistory, isEmpty);
        expect(
          container.read(gameControllerProvider).position.turn,
          Side.white,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await container.read(gameControllerProvider.notifier).shutdownEngines();
        container.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _showGame(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const GameScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('chess-board')));
void _expectVisible(WidgetTester tester) {
  final context = tester.element(find.byType(GameScreen));
  final media = MediaQuery.of(context);
  final rect = _rect(tester);
  expect(rect.top, greaterThanOrEqualTo(media.padding.top));
  expect(
    rect.bottom,
    lessThanOrEqualTo(media.size.height - media.padding.bottom),
  );
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(media.size.width));
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  final clock = Stopwatch()..start();
  do {
    await tester.pump(const Duration(milliseconds: 100));
    if (clock.elapsed > const Duration(minutes: 2)) {
      fail('Estado esperado não chegou em 2 minutos.');
    }
  } while (!done());
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _move(WidgetTester tester, String from, String to) async {
  await tester.tap(find.byKey(Key('board-semantics-$from')));
  await tester.pump();
  await tester.tap(find.byKey(Key('board-semantics-$to')));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _menu(WidgetTester tester, String option) async {
  await tester.tap(find.text('Mais'));
  await tester.pumpAndSettle();
  final target = find.text(option);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
