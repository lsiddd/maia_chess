// Test side/level selection and the error path when Maia-3 fails to start.

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_service.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_service.dart';
import 'package:maia_chess/features/difficulty/presentation/new_game_vs_ai_screen.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

void main() {
  testWidgets('allows side and level selection before starting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NewGameVsAiScreen())),
    );

    expect(
      tester
          .widget<SegmentedButton<Side>>(find.byType(SegmentedButton<Side>))
          .selected,
      {Side.white},
    );
    expect(_isChipSelected(tester, '600'), isTrue);
    expect(_isChipSelected(tester, '1300'), isFalse);

    await tester.tap(find.text('Black'));
    await tester.pump();
    expect(
      tester
          .widget<SegmentedButton<Side>>(find.byType(SegmentedButton<Side>))
          .selected,
      {Side.black},
    );

    await tester.tap(find.text('1300'));
    await tester.pump();
    expect(_isChipSelected(tester, '1300'), isTrue);
    expect(_isChipSelected(tester, '600'), isFalse);
  });

  testWidgets('shows an error when Maia-3 fails to start', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(_FakeGameRepository()),
          maiaEngineFactoryProvider.overrideWithValue(
            () => _FailingMaiaEngine(),
          ),
          stockfishEngineFactoryProvider.overrideWithValue(
            () => _FailingStockfishEngine(),
          ),
          maiaModelResolverProvider.overrideWithValue(
            () async => 'assets/maia3/maia3-79m-fp32.onnx',
          ),
        ],
        child: const MaterialApp(home: NewGameVsAiScreen()),
      ),
    );

    await tester.tap(find.text('Start game'));
    // pumpAndSettle covers the loading frame and the catch/SnackBar frame
    // without depending on wall-clock timing.
    await tester.pumpAndSettle();

    expect(find.textContaining('Maia-3:'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('Play against Maia-3'), findsOneWidget);
  });
}

bool _isChipSelected(WidgetTester tester, String label) {
  final chip = tester.widget<ChoiceChip>(
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
  );
  return chip.selected;
}

class _FakeGameRepository extends Fake implements GameRepository {}

class _FailingMaiaEngine extends Fake implements MaiaEngine {
  @override
  bool get isReady => false;

  @override
  Future<void> init(String weightsFilePath) async {
    throw StateError('Maia-3 failed to start (test)');
  }

  @override
  Future<void> dispose() async {}
}

class _FailingStockfishEngine extends Fake implements StockfishEngine {
  @override
  bool get isReady => false;

  @override
  Future<void> init() async {
    throw StateError('Stockfish failed to start (test)');
  }

  @override
  Future<void> dispose() async {}
}
