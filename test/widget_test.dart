// Smoke test: the home screen loads and exposes current entry points without
// the removed technical diagnostic.

import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'package:maia_chess/main.dart';

void main() {
  testWidgets('HomeScreen shows the expected entry points', (
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

    expect(find.text('Play (2 local players)'), findsOneWidget);
    expect(find.text('Maia-3 campaign'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('My performance'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My performance'), findsOneWidget);
    expect(find.text('Saved games and PGN'), findsOneWidget);
  });

  testWidgets('requests confirmation before replacing autosave', (
    WidgetTester tester,
  ) async {
    final active = _activeGame();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(_FakeGameRepository(active)),
          activeGameProvider.overrideWith(
            (ref) => Stream.value(GameSummary.fromGame(active)),
          ),
          appSettingsProvider.overrideWith(
            (ref) => Stream.value(const StoredAppSettings()),
          ),
        ],
        child: const MaiaChessApp(),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Play (2 local players)'));
    await tester.tap(find.text('Play (2 local players)'));
    await tester.pumpAndSettle();

    expect(find.text('Replace the ongoing game?'), findsOneWidget);
    expect(
      find.textContaining('will remove the current autosave'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Replace the ongoing game?'), findsNothing);
  });

  testWidgets('blocks opening another game during restore', (tester) async {
    final repository = _PendingGameRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repository),
          activeGameProvider.overrideWith(
            (ref) => Stream.value(GameSummary.fromGame(_activeGame())),
          ),
          appSettingsProvider.overrideWith(
            (ref) => Stream.value(const StoredAppSettings()),
          ),
        ],
        child: const MaiaChessApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue saved game'));
    // Two callbacks before rebuilding must also respect the opening guard.
    await tester.ensureVisible(find.text('Play (2 local players)'));
    await tester.tap(find.text('Play (2 local players)'));
    await tester.pump();
    expect(repository.reads, 1);
    repository.pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('There is no game to continue.'), findsOneWidget);
    expect(find.text('Replace the ongoing game?'), findsNothing);
  });
}

class _PendingGameRepository extends Fake implements GameRepository {
  final pending = Completer<StoredGame?>();
  int reads = 0;
  @override
  Future<StoredGame?> getActiveGame() {
    reads++;
    return pending.future;
  }
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
