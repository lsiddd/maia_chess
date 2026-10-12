import 'dart:convert';
import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/game_repository.dart';

class PgnFormatException implements Exception {
  const PgnFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PgnService {
  const PgnService();

  /// Keeps file validation and SAN replay off the UI isolate on Android.
  /// The synchronous API remains available for callers with small inputs.
  Future<StoredGame> parseImportAsync({
    required String pgn,
    required String id,
    required DateTime importedAtUtc,
  }) => compute(_parseImport, (
    pgn: pgn,
    id: id,
    importedAtUtc: importedAtUtc,
  ), debugLabel: 'PGN import');

  static StoredGame _parseImport(
    ({String pgn, String id, DateTime importedAtUtc}) request,
  ) => const PgnService().parseImport(
    pgn: request.pgn,
    id: request.id,
    importedAtUtc: request.importedAtUtc,
  );

  StoredGame parseImport({
    required String pgn,
    required String id,
    required DateTime importedAtUtc,
  }) {
    if (pgn.trim().isEmpty) {
      throw const PgnFormatException('The PGN file is empty.');
    }

    late final PgnGame<PgnNodeData> parsed;
    try {
      parsed = PgnGame.parsePgn(pgn);
    } catch (error) {
      throw PgnFormatException('Could not parse the PGN: $error');
    }

    late final Position initial;
    try {
      initial = PgnGame.startingPosition(parsed.headers);
    } catch (error) {
      throw PgnFormatException('The initial PGN position is invalid: $error');
    }
    if (initial is! Chess) {
      throw const PgnFormatException(
        'Only standard chess games can be imported.',
      );
    }

    final tokens = _mainlineSanTokens(pgn);
    final allTokens = _allSanTokens(pgn);
    final parsedMainline = parsed.moves.mainline().toList(growable: false);
    if (tokens.length != parsedMainline.length) {
      throw const PgnFormatException(
        'The PGN contains move text that could not be parsed.',
      );
    }

    var position = initial;
    final moves = <StoredGameMove>[];
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final move = position.parseSan(token);
      if (move == null) {
        throw PgnFormatException(
          'Invalid PGN move at ply ${index + 1}: "$token".',
        );
      }
      final (after, canonicalSan) = position.makeSan(move);
      position = after as Chess;
      moves.add(
        StoredGameMove(
          ply: index + 1,
          uci: move.uci,
          san: canonicalSan,
          fenAfter: position.fen,
          actor: GameMoveActor.imported,
          playedAtUtc: importedAtUtc.toUtc(),
        ),
      );
    }

    // The PGN parser is permissive. Replay each mainline move above, then
    // validate every recognised variation so syntactically accepted illegal
    // moves cannot pass.
    final parsedMoveCount = _validateVariations(parsed.moves, initial);
    if (allTokens.length != parsedMoveCount) {
      throw const PgnFormatException(
        'The PGN contains move text in a variation that could not be '
        'parsed.',
      );
    }

    final headerResult = parsed.headers['Result'] ?? '*';
    final result = switch (headerResult) {
      '1-0' => StoredGameResult.whiteWin,
      '0-1' => StoredGameResult.blackWin,
      '1/2-1/2' => StoredGameResult.draw,
      '*' => StoredGameResult.unknown,
      _ => throw PgnFormatException('Unknown PGN result: "$headerResult".'),
    };
    final importedAt = importedAtUtc.toUtc();
    return StoredGame(
      id: id,
      startedAtUtc: _dateFromHeaders(parsed.headers) ?? importedAt,
      endedAtUtc: importedAt,
      lastModifiedAtUtc: importedAt,
      status: StoredGameStatus.completed,
      result: result,
      termination: GameTermination.imported,
      evaluated: false,
      campaignMode: false,
      initialFen: initial.fen,
      currentFen: position.fen,
      pgn: parsed.makePgn(),
      moves: List.unmodifiable(moves),
    );
  }

  String export(StoredGame game) {
    final headers = PgnGame.defaultHeaders()
      ..['Event'] = game.levelRating == null
          ? 'Local game'
          : 'Maia Chess ${game.levelRating}'
      ..['Site'] = 'Maia Chess Offline'
      ..['Date'] = _formatPgnDate(game.startedAtUtc)
      ..['White'] = _playerName(game, Side.white)
      ..['Black'] = _playerName(game, Side.black)
      ..['Result'] = _resultToken(game.result)
      ..['Evaluated'] = game.evaluated ? 'true' : 'false';
    if (game.levelRating != null) {
      headers['MaiaLevel'] = '${game.levelRating}';
    }
    if (game.initialFen != Chess.initial.fen) {
      headers['SetUp'] = '1';
      headers['FEN'] = game.initialFen;
    }

    final root = PgnNode<PgnNodeData>();
    PgnNode<PgnNodeData> parent = root;
    for (final move in game.moves) {
      final child = PgnChildNode<PgnNodeData>(PgnNodeData(san: move.san));
      parent.children.add(child);
      parent = child;
    }
    return PgnGame<PgnNodeData>(
      headers: headers,
      moves: root,
      comments: const [],
    ).makePgn();
  }

  int _validateVariations(PgnNode<PgnNodeData> root, Position position) {
    var count = 0;
    final pending = <({PgnChildNode<PgnNodeData> node, Position before})>[
      for (final child in root.children.reversed)
        (node: child, before: position),
    ];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final move = current.before.parseSan(current.node.data.san);
      if (move == null) {
        throw PgnFormatException(
          'The PGN contains a variation with an illegal move: '
          '"${current.node.data.san}".',
        );
      }
      count++;
      final after = current.before.play(move);
      for (final child in current.node.children.reversed) {
        pending.add((node: child, before: after));
      }
    }
    return count;
  }

  List<String> _mainlineSanTokens(String source) {
    return _sanTokens(
      _stripHeadersAndComments(source, includeVariationText: false),
    );
  }

  List<String> _allSanTokens(String source) {
    return _sanTokens(
      _stripHeadersAndComments(source, includeVariationText: true),
    );
  }

  List<String> _sanTokens(String plain) {
    final result = <String>[];
    for (final raw in plain.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      var token = raw;
      token = token.replaceFirst(RegExp(r'^\d+\.(?:\.\.)?'), '');
      if (token.isEmpty ||
          token == '...' ||
          token == 'e.p.' ||
          RegExp(r'^\$\d+$').hasMatch(token) ||
          const {'1-0', '0-1', '1/2-1/2', '*'}.contains(token)) {
        continue;
      }
      token = token.replaceFirst(RegExp(r'[!?]+$'), '');
      if (token.isEmpty) continue;
      result.add(token);
    }
    return result;
  }

  String _stripHeadersAndComments(
    String source, {
    required bool includeVariationText,
  }) {
    final output = StringBuffer();
    var braceDepth = 0;
    var variationDepth = 0;
    var inHeader = false;
    var inHeaderString = false;
    var escaped = false;
    var lineComment = false;

    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (lineComment) {
        if (char == '\n') {
          lineComment = false;
          output.write(' ');
        }
        continue;
      }
      if (braceDepth > 0) {
        if (char == '{') braceDepth++;
        if (char == '}') braceDepth--;
        continue;
      }
      if (inHeader) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inHeaderString = !inHeaderString;
        } else if (char == ']' && !inHeaderString) {
          inHeader = false;
          output.write(' ');
        }
        continue;
      }
      if (char == ';') {
        lineComment = true;
      } else if (char == '{') {
        braceDepth = 1;
      } else if (char == '[' && variationDepth == 0) {
        inHeader = true;
      } else if (char == '(') {
        variationDepth++;
        if (includeVariationText) output.write(' ');
      } else if (char == ')' && variationDepth > 0) {
        variationDepth--;
        if (includeVariationText) output.write(' ');
      } else if (variationDepth == 0 || includeVariationText) {
        output.write(char);
      }
    }
    if (braceDepth != 0 || variationDepth != 0 || inHeader) {
      throw const PgnFormatException(
        'The PGN contains an unclosed comment, header, or variation.',
      );
    }
    return output.toString();
  }

  DateTime? _dateFromHeaders(PgnHeaders headers) {
    final value = headers['UTCDate'] ?? headers['Date'];
    if (value == null || value.contains('?')) return null;
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    try {
      return DateTime.utc(year, month, day);
    } on ArgumentError {
      return null;
    }
  }

  String _formatPgnDate(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}.'
        '${utc.month.toString().padLeft(2, '0')}.'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  String _playerName(StoredGame game, Side side) {
    if (game.levelRating == null) return 'Local player';
    return game.playerSide == side ? 'Player' : 'Maia ${game.levelRating}';
  }

  String _resultToken(StoredGameResult result) => switch (result) {
    StoredGameResult.whiteWin => '1-0',
    StoredGameResult.blackWin => '0-1',
    StoredGameResult.draw => '1/2-1/2',
    StoredGameResult.ongoing || StoredGameResult.unknown => '*',
  };
}

class PgnFileService {
  const PgnFileService();

  Future<String?> pickPgn() async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pgn'],
      withData: false,
    );
    if (selected == null) return null;
    final file = selected.files.single;
    final bytes = file.bytes;
    try {
      if (bytes != null) return await compute(_decodePgn, bytes);
      final path = file.path;
      if (path == null) {
        throw const PgnFormatException(
          'Android did not provide access to the selected file.',
        );
      }
      return await compute(_readPgn, path);
    } on FormatException {
      throw const PgnFormatException('The PGN file is not UTF-8 encoded.');
    }
  }

  static String _decodePgn(Uint8List bytes) => utf8.decode(bytes);

  static Future<String> _readPgn(String filename) =>
      io.File(filename).readAsString();

  Future<void> sharePgn({required String gameId, required String pgn}) async {
    final cache = await getTemporaryDirectory();
    final safeId = gameId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final file = io.File(p.join(cache.path, 'partida_$safeId.pgn'));
    await file.writeAsString(pgn, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/x-chess-pgn')],
        subject: 'Chess game',
        text: 'Game exported by Maia Chess.',
      ),
    );
  }
}
