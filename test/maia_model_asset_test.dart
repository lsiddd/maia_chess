import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_model_files.dart';

void main() {
  test(
    'Dart extraction verifies, caches and repairs a corrupt local model',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'maia-asset-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = List<int>.generate(32768, (i) => i % 251);
      final hash = sha256.convert(bytes).toString();
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'assets/flutter_assets/${MaiaModelFiles.asset}',
            bytes.length,
            bytes,
          ),
        );
      final apk = File('${directory.path}/app.apk');
      await apk.writeAsBytes(ZipEncoder().encode(archive));
      Future<String> extract() => MaiaModelFiles.extract(
        apkPaths: [apk.path],
        directory: '${directory.path}/models',
        expectedHash: hash,
        expectedBytes: bytes.length,
      );
      final path = await extract();
      expect(await File(path).readAsBytes(), bytes);
      final modified = await File(path).lastModified();
      expect(await extract(), path);
      expect(await File(path).lastModified(), modified);
      await File(path).writeAsBytes(List.filled(bytes.length, 0));
      await extract();
      expect(await File(path).readAsBytes(), bytes);
      expect(await File('$path.partial').exists(), isFalse);
    },
  );

  test(
    'a corrupt bundled asset is rejected without installing a partial model',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'maia-corrupt-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final archive = Archive()
        ..addFile(
          ArchiveFile('assets/flutter_assets/${MaiaModelFiles.asset}', 4, [
            1,
            2,
            3,
            4,
          ]),
        );
      final apk = File('${directory.path}/app.apk');
      await apk.writeAsBytes(ZipEncoder().encode(archive));
      final hash = sha256.convert([4, 3, 2, 1]).toString();
      await expectLater(
        MaiaModelFiles.extract(
          apkPaths: [apk.path],
          directory: '${directory.path}/models',
          expectedHash: hash,
          expectedBytes: 4,
        ),
        throwsStateError,
      );
      expect(
        await Directory('${directory.path}/models').list().toList(),
        isEmpty,
      );
    },
  );
}
