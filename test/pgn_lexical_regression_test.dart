import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';

void main() {
  test('rejects malformed annotation markers rather than dropping them', () {
    expect(
      () => const PgnService().parseImport(
        pgn: r'1. e4 $ e5 *',
        id: 'invalid',
        importedAtUtc: DateTime.utc(2026),
      ),
      throwsA(isA<PgnFormatException>()),
    );
  });
  for (final source in [
    r'1. e4$1 e5 *',
    '1 . e4 e5 *',
    '% escape line\n1. e4 e5 *',
  ]) {
    test('imports PGN lexical form $source', () {
      final parsed = PgnGame.parsePgn(source);
      expect(parsed.moves.mainline().length, 2);
      final result = const PgnService().parseImport(
        pgn: source,
        id: 'probe',
        importedAtUtc: DateTime.utc(2026),
      );
      expect(result.moves.length, 2);
    });
  }
}
