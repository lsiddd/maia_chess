import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';
import 'package:share_plus/share_plus.dart';

final class _PickedFile extends PlatformFile {
  _PickedFile(this.chunks, {this.reportedSize});

  final List<Uint8List> chunks;
  final int? reportedSize;
  int chunksRead = 0;

  @override
  String get name => 'game.pgn';
  @override
  Uri get uri => Uri.parse('content://test/game.pgn');
  @override
  XFile get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => reportedSize;
  @override
  Future<int?> length() async => reportedSize;
  @override
  Future<Uint8List> readAsBytes() => throw UnimplementedError();
  @override
  Stream<Uint8List> readAsByteStream() async* {
    for (final chunk in chunks) {
      chunksRead++;
      yield chunk;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canceling the file picker does not import a game', () async {
    final service = PgnFileService(pickFile: () async => null);
    expect(await service.pickPgn(), isNull);
  });

  test('reads UTF-8 content without a local path or known size', () async {
    final encoded = utf8.encode('[Event "São Paulo"]\n1. e4 *');
    final file = _PickedFile([
      Uint8List.fromList(encoded.sublist(0, 12)),
      Uint8List.fromList(encoded.sublist(12)),
    ]);
    expect(
      await PgnFileService(pickFile: () async => file).pickPgn(),
      '[Event "São Paulo"]\n1. e4 *',
    );
  });

  test('rejects an oversized file before reading any bytes', () async {
    final file = _PickedFile([], reportedSize: PgnService.maxImportBytes + 1);
    await expectLater(
      PgnFileService(pickFile: () async => file).pickPgn(),
      throwsA(isA<PgnFormatException>()),
    );
    expect(file.chunksRead, 0);
  });

  test('bounds content even when the provider understates its size', () async {
    final file = _PickedFile([
      Uint8List(PgnService.maxImportBytes),
      Uint8List(1),
      Uint8List(1),
    ], reportedSize: 1);
    await expectLater(
      PgnFileService(pickFile: () async => file).pickPgn(),
      throwsA(isA<PgnFormatException>()),
    );
    expect(file.chunksRead, 2);
  });

  test(
    'explains invalid UTF-8 instead of accepting replacement characters',
    () async {
      final file = _PickedFile([
        Uint8List.fromList([0xff]),
      ]);
      await expectLater(
        PgnFileService(pickFile: () async => file).pickPgn(),
        throwsA(
          isA<PgnFormatException>().having(
            (error) => error.toString(),
            'message',
            contains('UTF-8'),
          ),
        ),
      );
    },
  );
}
