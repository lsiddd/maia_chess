import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/repositories/drift_stats_repository.dart';

// Diagnostic only: measure real derived-state rebuilds before choosing a
// migration or an incremental rating algorithm.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('profile: rebuild and read statistics', (tester) async {
    final samples = <String, Object>{};
    const initialFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    for (final count in [1000, 5000]) {
      final directory = await Directory.systemTemp.createTemp('maia-stats-');
      final database = AppDatabase.forTesting(
        NativeDatabase.createInBackground(File('${directory.path}/stats.db')),
      );
      try {
        await database.batch((batch) {
          for (var i = 0; i < count; i++) {
            final date = DateTime.utc(2026).add(Duration(minutes: i));
            batch.insert(
              database.games,
              GamesCompanion.insert(
                id: 'game-$i',
                startedAtUtc: date,
                lastModifiedAtUtc: date,
                endedAtUtc: Value(date),
                status: const Value('completed'),
                result: Value(i.isEven ? 'whiteWin' : 'blackWin'),
                levelRating: Value(1100 + i % 9 * 100),
                playerSide: const Value('white'),
                evaluated: const Value(true),
                campaignMode: const Value(true),
                initialFen: initialFen,
                currentFen: initialFen,
              ),
            );
          }
        });
        final rebuilds = <Map<String, double>>[];
        final reads = <Map<String, double>>[];
        for (var sample = 0; sample < 6; sample++) {
          final rebuild = await _measure(
            () => database.transaction(database.rebuildDerivedState),
          );
          final read = await _measure(() async {
            final stats = await DriftStatsRepository(database).get();
            expect(stats.evaluatedGames, count);
            expect(stats.ratingHistory, hasLength(count));
          });
          if (sample > 0) {
            rebuilds.add(rebuild);
            reads.add(read);
          }
        }
        samples['$count'] = {'rebuild': rebuilds, 'read': reads};
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    }
    binding.reportData = {'stats_performance': samples};
  }, skip: !kProfileMode);
}

Future<Map<String, double>> _measure(Future<void> Function() operation) async {
  final clock = Stopwatch()..start();
  var lastTick = 0;
  var maxGap = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 2), (_) {
    final now = clock.elapsedMicroseconds;
    maxGap = max(maxGap, now - lastTick);
    lastTick = now;
  });
  try {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final work = Stopwatch()..start();
    await operation();
    work.stop();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return {
      'elapsed_ms': work.elapsedMicroseconds / 1000,
      'max_event_loop_gap_ms': maxGap / 1000,
    };
  } finally {
    timer.cancel();
  }
}
