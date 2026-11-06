import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_encoding.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_model_asset.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_service.dart';

import '../test/fixtures/maia3_reference.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'bundled 79M: official parity, cancellation and native recovery',
    (tester) async {
      final engine = MaiaService();
      final clock = Stopwatch()..start();
      final path = await MaiaModelAsset.resolve();
      final extractionMs = clock.elapsedMilliseconds;
      await engine.init(path);
      final startupMs = clock.elapsedMilliseconds - extractionMs;
      final latencies = <int>[];
      var maximumError = 0.0;
      try {
        final reference =
            jsonDecode(maia3ReferenceJson) as Map<String, dynamic>;
        for (final fixture
            in (reference['cases'] as List).cast<Map<String, dynamic>>()) {
          final positions = (fixture['fens'] as List)
              .map((fen) => Chess.fromSetup(Setup.parseFen(fen as String)))
              .toList();
          final expectedByLevel =
              fixture['probabilities'] as Map<String, dynamic>;
          for (final entry in expectedByLevel.entries) {
            final elo = int.parse(entry.key);
            clock.reset();
            final logits = await engine.policy(
              positions,
              selfElo: elo,
              opponentElo: elo,
            );
            latencies.add(clock.elapsedMilliseconds);
            final probabilities = MaiaEncoding.probabilities(
              logits,
              (fixture['legalIndices'] as List).cast<int>(),
            );
            final expected = (entry.value as List).cast<num>();
            for (var i = 0; i < expected.length; i++) {
              final error = (probabilities[i] - expected[i]).abs();
              if (error > maximumError) maximumError = error;
              expect(
                error,
                lessThanOrEqualTo(0.0001),
                reason: '${fixture['name']}, Elo $elo, index $i',
              );
            }
          }
        }
        final pending = engine.getMove(
          [Chess.initial],
          selfElo: 600,
          opponentElo: 600,
        );
        final cancelled = expectLater(pending, throwsStateError);
        engine.cancel();
        await cancelled;
        await engine.dispose();
        await engine.init(path);
        final move = await engine.getMove(
          [Chess.initial],
          selfElo: 2600,
          opponentElo: 2600,
        );
        expect(MaiaEncoding.legalMoves(Chess.initial).values, contains(move));
        await engine.dispose();
        await expectLater(engine.init('$path.missing'), throwsStateError);
        await engine.dispose();
        await engine.init(path);
        expect(engine.isReady, isTrue);
        latencies.sort();
        binding.reportData = {
          'model': 'Maia-3 79M FP32',
          'extraction_ms': extractionMs,
          'startup_ms': startupMs,
          'inferences': latencies.length,
          'median_ms': latencies[latencies.length ~/ 2],
          'p95_ms': latencies[(latencies.length * .95).floor()],
          'max_probability_error': maximumError,
          'rss_bytes': ProcessInfo.currentRss,
          'max_rss_bytes': ProcessInfo.maxRss,
        };
        // Captured in the integration log as well as flutter drive reports.
        // ignore: avoid_print
        print('MAIA3_VALIDATION ${jsonEncode(binding.reportData)}');
      } finally {
        await engine.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
