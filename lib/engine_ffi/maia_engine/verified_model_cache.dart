import 'dart:io';

/// Reuses a checksum-verified file only while its filesystem identity is stable.
/// The cache is process-local; a fresh process always verifies the checksum.
class VerifiedModelCache {
  Future<String>? _pending;
  ({String path, FileStat stat})? _verified;

  Future<String> resolve(Future<String> Function() verify) =>
      _pending ??= _resolve(verify).whenComplete(() => _pending = null);

  Future<String> _resolve(Future<String> Function() verify) async {
    final cached = _verified;
    if (cached != null) {
      final stat = await File(cached.path).stat();
      if (stat.type == FileSystemEntityType.file &&
          stat.size == cached.stat.size &&
          stat.modified == cached.stat.modified &&
          stat.changed == cached.stat.changed) {
        return cached.path;
      }
    }
    final path = await verify();
    _verified = (path: path, stat: await File(path).stat());
    return path;
  }
}
