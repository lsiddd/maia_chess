import 'dart:convert';
import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';
import 'package:file_picker/file_picker.dart';
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

  StoredGame parseImport({
    required String pgn,
    required String id,
    required DateTime importedAtUtc,
  }) {
    if (pgn.trim().isEmpty) {
      throw const PgnFormatException('O arquivo PGN está vazio.');
    }

    late final PgnGame<PgnNodeData> parsed;
    try {
      parsed = PgnGame.parsePgn(pgn);
    } catch (error) {
      throw PgnFormatException('Não foi possível interpretar o PGN: $error');
    }

    late final Position initial;
    try {
      initial = PgnGame.startingPosition(parsed.headers);
    } catch (error) {
      throw PgnFormatException('A posição inicial do PGN é inválida: $error');
    }
    if (initial is! Chess) {
      throw const PgnFormatException(
        'Somente partidas de xadrez clássico podem ser importadas.',
      );
    }

    final tokens = _mainlineSanTokens(pgn);
    final allTokens = _allSanTokens(pgn);
    final parsedMainline = parsed.moves.mainline().toList(growable: false);
    if (tokens.length != parsedMainline.length) {
      throw const PgnFormatException(
        'O PGN contém texto de lance que não pôde ser interpretado.',
      );
    }

    var position = initial;
    final moves = <StoredGameMove>[];
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final move = position.parseSan(token);
      if (move == null) {
        throw PgnFormatException(
          'Lance inválido no PGN, jogada ${index + 1}: "$token".',
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

    // O parser é permissivo por design. A validação acima reaplica cada
    // lance principal; esta passagem adicional impede que uma variante
    // sintaticamente reconhecida contenha lances ilegais.
    final parsedMoveCount = _validateVariations(parsed.moves, initial);
    if (allTokens.length != parsedMoveCount) {
      throw const PgnFormatException(
        'O PGN contém texto de lance em uma variante que não pôde ser '
        'interpretado.',
      );
    }

    final headerResult = parsed.headers['Result'] ?? '*';
    final result = switch (headerResult) {
      '1-0' => StoredGameResult.whiteWin,
      '0-1' => StoredGameResult.blackWin,
      '1/2-1/2' => StoredGameResult.draw,
      '*' => StoredGameResult.unknown,
      _ => throw PgnFormatException(
        'Resultado PGN desconhecido: "$headerResult".',
      ),
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
          ? 'Partida local'
          : 'Xadrez Maia ${game.levelRating}'
      ..['Site'] = 'Xadrez Maia Offline'
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
    for (final child in root.children) {
      final move = position.parseSan(child.data.san);
      if (move == null) {
        throw PgnFormatException(
          'O PGN contém uma variante com lance ilegal: '
          '"${child.data.san}".',
        );
      }
      count += 1 + _validateVariations(child, position.play(move));
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
        'O PGN possui comentário, cabeçalho ou variante sem fechamento.',
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
    if (game.levelRating == null) return 'Jogador local';
    return game.playerSide == side ? 'Jogador' : 'Maia ${game.levelRating}';
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
      withData: true,
    );
    if (selected == null) return null;
    final file = selected.files.single;
    final bytes = file.bytes;
    try {
      if (bytes != null) return utf8.decode(bytes);
      final path = file.path;
      if (path == null) {
        throw const PgnFormatException(
          'O Android não forneceu acesso ao arquivo selecionado.',
        );
      }
      return io.File(path).readAsString();
    } on FormatException {
      throw const PgnFormatException('O arquivo PGN não está em UTF-8.');
    }
  }

  Future<void> sharePgn({required String gameId, required String pgn}) async {
    final cache = await getTemporaryDirectory();
    final safeId = gameId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final file = io.File(p.join(cache.path, 'partida_$safeId.pgn'));
    await file.writeAsString(pgn, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/x-chess-pgn')],
        subject: 'Partida de xadrez',
        text: 'Partida exportada pelo Xadrez Maia.',
      ),
    );
  }
}
