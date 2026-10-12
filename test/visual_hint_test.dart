// Regression for the former dialog: hints are now exclusively visual.
import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'game_controller_test.dart' show FakeGameRepository, FakeStockfishEngine;
import 'support_game_settings.dart';
import 'opponent_threats_test.dart' show PositionedController;

void main() {
  testWidgets(
    'a hint in a terminal position reports no move without querying the engine',
    (tester) async {
      final settings = MemorySettings();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          gameControllerProvider.overrideWith(
            () => PositionedController('4k3/8/8/8/8/8/8/4K3 b - - 0 1'),
          ),
          stockfishEngineFactoryProvider.overrideWithValue(
            () => throw StateError('Must not start'),
          ),
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
      final rect = tester.getRect(find.byKey(const Key('chess-board')));
      await tester.tap(find.byKey(const Key('hint-button')));
      await tester.pumpAndSettle();
      expect(find.text('Game over: no move is available.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.getRect(find.byKey(const Key('chess-board'))), rect);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'hint has no dialog or destination, stable loading, and clears on interaction',
    (tester) async {
      final reply = Completer<String>();
      final settings = MemorySettings();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          stockfishEngineFactoryProvider.overrideWithValue(
            () => FakeStockfishEngine(onMove: (_, _) => reply.future),
          ),
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
      final rect = tester.getRect(find.byKey(const Key('chess-board')));
      await tester.tap(find.byKey(const Key('hint-button')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('chess-board'))), rect);
      expect(find.byType(AlertDialog), findsNothing);
      reply.complete('e2e4');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hint-origin-indicator')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('board-square-6-4')),
          matching: find.byKey(const Key('hint-origin-indicator')),
        ),
        findsOneWidget,
      );
      expect(find.text('e4'), findsNothing);
      expect(tester.getRect(find.byKey(const Key('chess-board'))), rect);
      await tester.tap(find.byKey(const Key('hint-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hint-origin-indicator')), findsNothing);
      await tester.tap(find.byKey(const Key('hint-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('board-square-6-4')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hint-origin-indicator')), findsNothing);
      expect(container.read(gameControllerProvider).selectedSquare, Square.e2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
