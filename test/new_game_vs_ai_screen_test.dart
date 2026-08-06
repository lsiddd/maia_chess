// Cobre AUDITORIA_TECNICA.md, AUD-004: NewGameVsAiScreen estava com 2% de
// cobertura. Testa a seleção de lado/nível e o caminho de erro quando o
// motor Maia falha ao iniciar.

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/engine_ffi/lc0_engine/lc0_service.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_service.dart';
import 'package:maia_chess/features/difficulty/presentation/new_game_vs_ai_screen.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

void main() {
  testWidgets('permite selecionar lado e nível antes de começar', (
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
    expect(_isChipSelected(tester, '1100'), isTrue);
    expect(_isChipSelected(tester, '1300'), isFalse);

    await tester.tap(find.text('Pretas'));
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
    expect(_isChipSelected(tester, '1100'), isFalse);
  });

  testWidgets('mostra erro quando o motor Maia falha ao iniciar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(_FakeGameRepository()),
          lc0EngineFactoryProvider.overrideWithValue(() => _FailingLc0Engine()),
          stockfishEngineFactoryProvider.overrideWithValue(
            () => _FailingStockfishEngine(),
          ),
          maiaWeightsResolverProvider.overrideWithValue(
            (level) async => level.weightsAsset,
          ),
        ],
        child: const MaterialApp(home: NewGameVsAiScreen()),
      ),
    );

    await tester.tap(find.text('Começar partida'));
    // Carregamento do motor falho: um frame para o spinner, outro para o
    // catch/SnackBar; pumpAndSettle cobre os dois sem depender de tempo real.
    await tester.pumpAndSettle();

    expect(find.textContaining('Maia:'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('Jogar contra a IA Maia'), findsOneWidget);
  });
}

bool _isChipSelected(WidgetTester tester, String label) {
  final chip = tester.widget<ChoiceChip>(
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
  );
  return chip.selected;
}

class _FakeGameRepository extends Fake implements GameRepository {}

class _FailingLc0Engine extends Fake implements Lc0Engine {
  @override
  bool get isReady => false;

  @override
  Future<void> init(String weightsFilePath) async {
    throw StateError('lc0 falhou ao iniciar (teste)');
  }

  @override
  Future<void> dispose() async {}
}

class _FailingStockfishEngine extends Fake implements StockfishEngine {
  @override
  bool get isReady => false;

  @override
  Future<void> init() async {
    throw StateError('Stockfish falhou ao iniciar (teste)');
  }

  @override
  Future<void> dispose() async {}
}
