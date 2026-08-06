// Teste de fumaça: a tela inicial sobe sem erros e mostra os pontos de
// entrada esperados (Fase 1: jogo local; Fase 0: diagnóstico técnico).

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'package:maia_chess/main.dart';

void main() {
  testWidgets('HomeScreen mostra os pontos de entrada esperados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeGameProvider.overrideWith((ref) => Stream.value(null)),
          appSettingsProvider.overrideWith(
            (ref) => Stream.value(const StoredAppSettings()),
          ),
        ],
        child: const MaiaChessApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Jogar (2 jogadores locais)'), findsOneWidget);
    expect(find.text('Campanha Maia'), findsOneWidget);
    expect(find.text('Meu desempenho'), findsOneWidget);
    expect(find.text('Partidas salvas e PGN'), findsOneWidget);
    expect(find.text('Diagnóstico técnico (Fase 0)'), findsNothing);
  });

  testWidgets('pede confirmação antes de substituir o autosave', (
    WidgetTester tester,
  ) async {
    final active = _activeGame();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(_FakeGameRepository(active)),
          activeGameProvider.overrideWith((ref) => Stream.value(active)),
          appSettingsProvider.overrideWith(
            (ref) => Stream.value(const StoredAppSettings()),
          ),
        ],
        child: const MaiaChessApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Jogar (2 jogadores locais)'));
    await tester.pumpAndSettle();

    expect(find.text('Substituir partida em andamento?'), findsOneWidget);
    expect(find.textContaining('autosave atual será removido'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Substituir partida em andamento?'), findsNothing);
  });
}

class _FakeGameRepository extends Fake implements GameRepository {
  _FakeGameRepository(this.active);

  final StoredGame active;

  @override
  Future<StoredGame?> getActiveGame() async => active;
}

StoredGame _activeGame() {
  final now = DateTime.utc(2026, 8, 5);
  return StoredGame(
    id: 'active',
    startedAtUtc: now,
    lastModifiedAtUtc: now,
    status: StoredGameStatus.ongoing,
    result: StoredGameResult.ongoing,
    evaluated: true,
    campaignMode: false,
    initialFen: Chess.initial.fen,
    currentFen: Chess.initial.fen,
    moves: const [],
  );
}
