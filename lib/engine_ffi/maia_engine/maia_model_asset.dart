import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'maia_model_files.dart';
import 'verified_model_cache.dart';

/// Model provisioning is entirely local. Android only supplies APK paths;
/// Dart streams the asset, verifies SHA-256 and atomically installs the file.
abstract final class MaiaModelAsset {
  static const asset = 'assets/maia3/maia3-79m-fp32.onnx';
  static const manifestAsset = 'assets/maia3/manifest.json';
  static const _channel = MethodChannel('maia_chess/package_assets');
  static final _cache = VerifiedModelCache();
  static Future<String> resolve() => _cache.resolve(_resolve);

  static Future<String> _resolve() async {
    final manifest =
        jsonDecode(await rootBundle.loadString(manifestAsset))
            as Map<String, dynamic>;
    final directory = await getApplicationSupportDirectory();
    final apks = await _channel.invokeListMethod<String>('apkPaths');
    if (apks == null || apks.isEmpty) {
      throw StateError('Android package assets unavailable');
    }
    return Isolate.run(
      () => MaiaModelFiles.extract(
        apkPaths: apks,
        directory: '${directory.path}/maia3',
        expectedHash: manifest['sha256'] as String,
        expectedBytes: manifest['bytes'] as int,
      ),
    );
  }
}
