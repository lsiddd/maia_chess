import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:maia_chess/core/constants/difficulty_levels.dart';

Future<void> main() async {
  final directory = Directory('assets/maia3');
  final manifest =
      jsonDecode(await File('${directory.path}/manifest.json').readAsString())
          as Map<String, dynamic>;
  final file = File('${directory.path}/${manifest['file']}');
  if (!await file.exists() || await file.length() != manifest['bytes']) {
    stderr.writeln(
      'Maia-3 model missing or incomplete. Run git lfs install and git lfs pull.',
    );
    exitCode = 1;
    return;
  }
  final hash = (await sha256.bind(file.openRead()).first).toString();
  final levels = DifficultyLevel.all.map((level) => level.rating).toList();
  if (hash != manifest['sha256'] ||
      jsonEncode(levels) != jsonEncode(manifest['levels'])) {
    stderr.writeln(
      'Maia-3 hash or level catalog does not match manifest.json.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Verified Maia-3 79M FP32: ${manifest['bytes']} bytes, ${levels.length} levels, SHA-256 $hash',
  );
}
