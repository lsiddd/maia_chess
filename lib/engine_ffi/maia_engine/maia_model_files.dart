import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

/// Streaming model installation shared by the app and Dart release checks.
abstract final class MaiaModelFiles {
  static const asset = 'assets/maia3/maia3-79m-fp32.onnx';

  /// Public for streaming/corruption tests using a small synthetic APK.
  static Future<String> extract({
    required List<String> apkPaths,
    required String directory,
    required String expectedHash,
    required int expectedBytes,
  }) async {
    final targetDirectory = Directory(directory);
    await targetDirectory.create(recursive: true);
    final target = File('$directory/$expectedHash.onnx');
    Future<bool> valid(File file) async =>
        await file.exists() &&
        await file.length() == expectedBytes &&
        (await sha256.bind(file.openRead()).first).toString() == expectedHash;
    if (await valid(target)) return target.path;
    final temporary = File('${target.path}.partial');
    try {
      var found = false;
      for (final apk in apkPaths) {
        final input = InputFileStream(apk);
        try {
          final archive = ZipDecoder().decodeStream(input);
          final entry = archive.findFile('assets/flutter_assets/$asset');
          if (entry == null) continue;
          if (entry.size != expectedBytes) {
            throw StateError('Maia-3 asset size mismatch; reinstall the app');
          }
          final output = OutputFileStream(temporary.path);
          try {
            entry.writeContent(output);
          } finally {
            await output.close();
          }
          found = true;
          break;
        } finally {
          await input.close();
        }
      }
      if (!found) {
        throw StateError('Bundled Maia-3 model not found; reinstall the app');
      }
      if (!await valid(temporary)) {
        throw StateError('Maia-3 checksum mismatch; reinstall the app');
      }
      await temporary.rename(target.path);
      return target.path;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
