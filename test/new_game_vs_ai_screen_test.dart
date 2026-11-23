// Test side/level selection and the error path when Maia-3 fails to start.

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/data/repositories/progress_repository.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_service.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_service.dart';
import 'package:maia_chess/features/difficulty/domain/campaign_wins.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/difficulty/presentation/new_game_vs_ai_screen.dart';
import 'package:maia_chess/features/difficulty/presentation/side_picker.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;
import 'support_game_settings.dart';

void main() {
  testWidgets('allows side and level selection before starting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NewGameVsAiScreen())),
    );

    expect(
      tester
          .widget<SegmentedButton<SideChoice>>(
            find.byType(SegmentedButton<SideChoice>),
          )
          .selected,
      {SideChoice.white},
    );
    expect(_isChipSelected(tester, '600'), isTrue);
    expect(_isChipSelected(tester, '1300'), isFalse);

    await tester.tap(find.text('Black'));
    await tester.pump();
    expect(
      tester
          .widget<SegmentedButton<SideChoice>>(
            find.byType(SegmentedButton<SideChoice>),
          )
          .selected,
      {SideChoice.black},
    );

    await tester.tap(find.text('Random'));
    await tester.pump();
    expect(find.text('Maia-3 600 · Random · Unlimited time'), findsOneWidget);

    await tester.tap(find.text('1300'));
    await tester.pump();
    expect(_isChipSelected(tester, '1300'), isTrue);
    expect(_isChipSelected(tester, '600'), isFalse);
  });

  for (final campaign in [false, true]) {
    testWidgets(
      'Random starts and saves a game with the drawn side (campaign=$campaign)',
      (tester) async {
        final games = FakeGameRepository();
        final settings = MemorySettings();
        addTearDown(settings.close);
        final container = ProviderContainer(
          overrides: [
            gameRepositoryProvider.overrideWithValue(games),
            settingsRepositoryProvider.overrideWithValue(settings),
            maiaEngineFactoryProvider.overrideWithValue(
              () => FakeMaiaEngine(onMove: (_, _) async => 'e2e4'),
            ),
            maiaModelResolverProvider.overrideWithValue(() async => 'fixture'),
            difficultyProgressProvider.overrideWith(
              (_) => Stream.value([
                DifficultyProgressModel(
                  rating: 600,
                  wins: const CampaignWins(),
                  unlocked: true,
                  updatedAtUtc: DateTime.utc(2026),
                ),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: campaign
                  ? const CampaignScreen()
                  : const NewGameVsAiScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (campaign) {
          await tester.tap(find.text('Game setup'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Random'));
        await tester.tap(find.text('Random'));
        await tester.pumpAndSettle();
        final start = find.text(campaign ? 'Play level' : 'Start game');
        if (campaign) await tester.scrollUntilVisible(start, 200);
        await tester.tap(start);
        await tester.pumpAndSettle();
        final saved = games.games.values.single;
        expect(find.byType(GameScreen), findsOneWidget);
        expect(saved.campaignMode, campaign);
        expect(saved.playerSide, isIn(Side.values));
        expect(
          container.read(gameControllerProvider).aiSide,
          saved.playerSide!.opposite,
        );
        expect(saved.moves.length, saved.playerSide == Side.black ? 1 : 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

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

    await tester.scrollUntilVisible(find.text('Start game'), 300);
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
