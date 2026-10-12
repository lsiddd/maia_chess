import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = PgnService();
  final date = DateTime.utc(2026, 10, 11);

  test(
    'worker preserves moves, variations, comments, FEN, and metadata',
    () async {
      const source = '''
[Event "Worker"]
[X-Custom "preserved"]
[Result "*"]

1. e4 {free-form comment} e5 2. Nf3 (2. Bc4 Nc6) Nc6 *
''';
      final sync = service.parseImport(
        pgn: source,
        id: 'worker',
        importedAtUtc: date,
      );
      final fromWorker = await service.parseImportAsync(
        pgn: source,
        id: 'worker',
        importedAtUtc: date,
      );
      expect(fromWorker.pgn, sync.pgn);
      expect(fromWorker.currentFen, sync.currentFen);
      expect(fromWorker.initialFen, sync.initialFen);
      expect(fromWorker.startedAtUtc, sync.startedAtUtc);
      expect(fromWorker.evaluated, sync.evaluated);
      expect(
        fromWorker.moves.map((move) => move.uci),
        sync.moves.map((move) => move.uci),
      );
      expect(const GameReplayer().replay(fromWorker).positions, hasLength(5));
    },
  );

  for (final source in [
    '',
    '1. e4 e5 2. Bh6 *',
    '1. e4 e5 2. Nf3 (2. Bh6) *',
  ]) {
    test('worker propagates validation errors: $source', () async {
      await expectLater(
        service.parseImportAsync(
          pgn: source,
          id: 'invalid',
          importedAtUtc: date,
        ),
        throwsA(isA<PgnFormatException>()),
      );
    });
  }

  test('validates a long sequence without recursion per move', () async {
    final source = StringBuffer();
    for (var cycle = 0; cycle < 1000; cycle++) {
      source.write('${cycle * 2 + 1}. Nf3 Nf6 ${cycle * 2 + 2}. Ng1 Ng8 ');
    }
    source.write('*');
    final game = await service.parseImportAsync(
      pgn: source.toString(),
      id: 'long',
      importedAtUtc: date,
    );
    expect(game.moves, hasLength(4000));
    expect(game.moves.last.san, 'Ng8');
  });
}
