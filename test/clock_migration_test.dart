import 'dart:io' as io;
import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';

void main() {
  test(
    'schema 5 migration preserves autosave and defaults increment to zero',
    () async {
      final directory = await io.Directory.systemTemp.createTemp(
        'maia-clock-migration-',
      );
      final file = io.File('${directory.path}/games.sqlite');
      final legacy = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await DriftGameRepository(legacy).beginGame(
          StoredGame(
            id: 'timed-game',
            startedAtUtc: DateTime.utc(2026),
            lastModifiedAtUtc: DateTime.utc(2026),
            status: StoredGameStatus.ongoing,
            result: StoredGameResult.ongoing,
            evaluated: true,
            campaignMode: false,
            initialFen: Chess.initial.fen,
            currentFen: Chess.initial.fen,
            moves: const [],
            clockEnabled: true,
            initialTimeMs: 60000,
            whiteTimeMs: 45000,
            blackTimeMs: 60000,
          ),
        );
        await legacy.customStatement(
          'ALTER TABLE games DROP COLUMN increment_ms',
        );
        await legacy.customStatement('PRAGMA user_version = 5');
      } finally {
        await legacy.close();
      }
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final restored = await DriftGameRepository(upgraded).getActiveGame();
        expect(restored!.id, 'timed-game');
        expect(restored.whiteTimeMs, 45000);
        expect(restored.blackTimeMs, 60000);
        expect(restored.incrementMs, 0);
        expect(restored.clockEnabled, isTrue);
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
