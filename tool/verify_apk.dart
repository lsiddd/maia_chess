import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_model_files.dart';

/// Verifies the actual bundled bytes, ARM64 engines and 16 KB ELF alignment.
Future<void> verifyApk(String path) async {
  final input = InputFileStream(path);
  final temporary = await Directory.systemTemp.createTemp('maia-apk-check-');
  try {
    final archive = ZipDecoder().decodeStream(input);
    final names = archive.files.map((file) => file.name).toList();
    if (names.toSet().length != names.length) {
      throw StateError('Duplicate APK entries');
    }
    final models = names.where((name) => name.endsWith('.onnx')).toList();
    if (models.length != 1 ||
        models.single != 'assets/flutter_assets/${MaiaModelFiles.asset}') {
      throw StateError('APK must contain exactly one Maia-3 model');
    }
    if (names.any(
      (name) =>
          name.contains('lc0') ||
          name.contains('leela_chess_zero') ||
          name.endsWith('.pb.gz'),
    )) {
      throw StateError('Legacy Maia/lc0 files remain in APK');
    }
    for (final name in ['app', 'flutter', 'stockfish', 'onnxruntime']) {
      if (!names.contains('lib/arm64-v8a/lib$name.so')) {
        throw StateError('Missing native library: $name');
      }
    }
    for (final file in archive.files.where(
      (file) => file.name.startsWith('lib/') && file.isFile,
    )) {
      if (!file.name.startsWith('lib/arm64-v8a/')) {
        throw StateError('Non-ARM64 library: ${file.name}');
      }
      final outputPath = '${temporary.path}/${file.name.split('/').last}';
      final output = OutputFileStream(outputPath);
      try {
        file.writeContent(output);
      } finally {
        await output.close();
      }
      final library = await File(outputPath).open();
      try {
        final header = ByteData.sublistView(await library.read(64));
        if (header.lengthInBytes != 64 ||
            header.getUint32(0, Endian.little) != 0x464c457f ||
            header.getUint8(4) != 2 ||
            header.getUint16(18, Endian.little) != 183) {
          throw StateError('Invalid ARM64 ELF: ${file.name}');
        }
        final offset = header.getUint64(32, Endian.little);
        final size = header.getUint16(54, Endian.little);
        final count = header.getUint16(56, Endian.little);
        await library.setPosition(offset);
        final programs = ByteData.sublistView(await library.read(size * count));
        for (var i = 0; i < count; i++) {
          final start = i * size;
          if (programs.getUint32(start, Endian.little) == 1 &&
              programs.getUint64(start + 48, Endian.little) < 16384) {
            throw StateError(
              'ELF LOAD segment is not 16 KB aligned: ${file.name}',
            );
          }
        }
      } finally {
        await library.close();
      }
    }
    final manifestEntry = archive.findFile(
      'assets/flutter_assets/assets/maia3/manifest.json',
    );
    if (manifestEntry == null) throw StateError('Missing Maia-3 manifest');
    final manifest =
        jsonDecode(utf8.decode(manifestEntry.content)) as Map<String, dynamic>;
    final source =
        jsonDecode(await File('assets/maia3/manifest.json').readAsString())
            as Map<String, dynamic>;
    if (manifest['sha256'] != source['sha256'] ||
        manifest['bytes'] != source['bytes']) {
      throw StateError('APK model does not match repository manifest');
    }
    await MaiaModelFiles.extract(
      apkPaths: [path],
      directory: '${temporary.path}/model',
      expectedHash: manifest['sha256'] as String,
      expectedBytes: manifest['bytes'] as int,
    );
  } finally {
    await input.close();
    await temporary.delete(recursive: true);
  }
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/verify_apk.dart PATH.apk');
    exitCode = 1;
    return;
  }
  try {
    await verifyApk(arguments.single);
    stdout.writeln(
      'ARM64 APK verified: Maia-3 79M, Stockfish, SHA-256 and 16 KB ELF alignment.',
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
