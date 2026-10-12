import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'support_game_settings.dart';

void main() {
  Future<void> pumpGameAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    final settings = MemorySettings();
    addTearDown(settings.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: child!,
          ),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menu respects bottom navigation with enlarged text', (
    tester,
  ) async {
    await pumpGameAt(tester, const Size(320, 480), textScale: 2);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(viewport.bottom, lessThanOrEqualTo(456));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 480),
    const Size(400, 800),
    const Size(800, 400),
    const Size(600, 320),
  ]) {
    testWidgets(
      '64 visible squares and stable geometry at $size with 2x text',
      (tester) async {
        await pumpGameAt(tester, size, textScale: 2);
        final board = find.byKey(const Key('chess-board'));
        final rect = tester.getRect(board);
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.width, rect.height);
        for (var r = 0; r < 8; r++) {
          for (var c = 0; c < 8; c++) {
            final square = tester.getRect(
              find.byKey(ValueKey('board-square-$r-$c')),
            );
            expect(rect.contains(square.center), isTrue);
            expect(square.width, closeTo(rect.width / 8, .01));
          }
        }
        await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
        await tester.pumpAndSettle();
        expect(tester.getRect(board), rect);
        await tester.tap(find.byKey(const Key('toggle-attacked-pieces')));
        await tester.pumpAndSettle();
        expect(tester.getRect(board), rect);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'history review preserves the board and restart requests confirmation',
    (tester) async {
      await pumpGameAt(tester, const Size(400, 800));
      await tester.tap(find.byKey(const Key('board-square-6-4')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('board-square-4-4')));
      await tester.pumpAndSettle();
      expect(find.text('1. e4'), findsOneWidget);
      final rect = tester.getRect(find.byKey(const Key('chess-board')));
      await tester.tap(find.byKey(const Key('move-list-panel')));
      await tester.pumpAndSettle();
      expect(find.text('Current position'), findsOneWidget);
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close history'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('chess-board'))), rect);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(find.text('Restart game?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('1. e4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
