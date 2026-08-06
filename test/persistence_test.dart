import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/data/repositories/drift_progress_repository.dart';
import 'package:maia_chess/data/repositories/drift_settings_repository.dart';
import 'package:maia_chess/data/repositories/drift_stats_repository.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';
import 'package:maia_chess/features/stats/domain/player_stats.dart';

void main() {
  late AppDatabase database;
  late DriftGameRepository games;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    games = DriftGameRepository(database);
  });

  tearDown(() => database.close());

  group('schema e migração inicial', () {
    test('cria tabelas, versão, defaults e chaves estrangeiras', () async {
      final version = await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle();
      final tables = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row.read<String>('name'))
          .get();
      final progress = await DriftProgressRepository(database).getAll();
      final settings = await DriftSettingsRepository(database).get();
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .map((row) => row.read<int>('foreign_keys'))
          .getSingle();

      expect(version, 2);
      expect(
        tables,
        containsAll([
          'games',
          'game_moves',
          'difficulty_progress',
          'rating_history',
          'app_settings',
        ]),
      );
      expect(progress.map((row) => row.rating), [
        1100,
        1200,
        1300,
        1400,
        1500,
        1600,
        1700,
        1800,
        1900,
      ]);
      expect(progress.first.unlocked, isTrue);
      expect(progress.skip(1).every((row) => !row.unlocked), isTrue);
      expect(progress.every((row) => row.gamesInWindow == 0), isTrue);
      expect(progress.every((row) => row.winsRequired == 2), isTrue);
      expect(progress.every((row) => row.windowSize == 3), isTrue);
      expect(settings.defaultTimeMinutes, 10);
      expect(foreignKeys, 1);
    });

    test(
      'migração v1 -> v2 acrescenta janela e reconstrói projeções',
      () async {
        await database.close();
        final migrated = AppDatabase.forTesting(
          NativeDatabase.memory(
            setup: (raw) {
              raw
                ..execute('''
                CREATE TABLE games (
                  id TEXT NOT NULL PRIMARY KEY,
                  started_at_utc INTEGER NOT NULL,
                  ended_at_utc INTEGER,
                  last_modified_at_utc INTEGER NOT NULL,
                  status TEXT NOT NULL DEFAULT 'ongoing',
                  level_rating INTEGER,
                  player_side TEXT,
                  result TEXT NOT NULL DEFAULT 'ongoing',
                  termination TEXT,
                  evaluated INTEGER NOT NULL DEFAULT 1,
                  campaign_mode INTEGER NOT NULL DEFAULT 0,
                  initial_fen TEXT NOT NULL,
                  current_fen TEXT NOT NULL,
                  pgn TEXT,
                  clock_enabled INTEGER NOT NULL DEFAULT 0,
                  initial_time_ms INTEGER,
                  white_time_ms INTEGER,
                  black_time_ms INTEGER
                )
              ''')
                ..execute('''
                CREATE TABLE difficulty_progress (
                  rating INTEGER NOT NULL PRIMARY KEY,
                  valid_wins INTEGER NOT NULL DEFAULT 0,
                  unlocked INTEGER NOT NULL DEFAULT 0,
                  updated_at_utc INTEGER NOT NULL
                )
              ''')
                ..execute('''
                CREATE TABLE rating_history (
                  id TEXT NOT NULL PRIMARY KEY,
                  game_id TEXT NOT NULL UNIQUE,
                  recorded_at_utc INTEGER NOT NULL,
                  rating REAL NOT NULL
                )
              ''')
                ..execute('PRAGMA user_version = 1');
            },
          ),
        );
        addTearDown(migrated.close);

        final version = await migrated
            .customSelect('PRAGMA user_version')
            .map((row) => row.read<int>('user_version'))
            .getSingle();
        final columns = await migrated
            .customSelect('PRAGMA table_info(difficulty_progress)')
            .map((row) => row.read<String>('name'))
            .get();
        final progress = await DriftProgressRepository(migrated).getAll();

        expect(version, 2);
        expect(columns, contains('window_games'));
        expect(progress, hasLength(9));
        expect(progress.first.unlocked, isTrue);
        expect(progress.every((item) => item.gamesInWindow == 0), isTrue);
      },
    );

    test('excluir a partida remove seus lances por cascade', () async {
      final game = _ongoingGame('cascade', ['e2e4']);
      await games.beginGame(game);
      await games.deleteGame(game.id);

      expect(await database.select(database.gameMoves).get(), isEmpty);
    });
  });

  group('repositório transacional', () {
    test('autosave substitui snapshot e remove lances desfeitos', () async {
      final first = _ongoingGame('autosave', ['e2e4', 'e7e5']);
      await games.beginGame(first);
      await games.saveOngoing(_ongoingGame('autosave', ['e2e4']));

      final restored = await games.getActiveGame();
      expect(restored, isNotNull);
      expect(restored!.moves.map((move) => move.uci), ['e2e4']);
      expect(restored.currentFen, restored.moves.single.fenAfter);
      expect(const GameReplayer().replay(restored).positions, hasLength(2));
    });

    test('começar outra partida elimina apenas o autosave anterior', () async {
      await games.beginGame(_ongoingGame('old', ['d2d4']));
      await games.beginGame(_ongoingGame('new', const []));

      final library = await games.watchLibrary().first;
      expect(library.map((game) => game.id), ['new']);
    });

    test('finalização e vitória de campanha são idempotentes', () async {
      final ongoing = _ongoingGame(
        'campaign',
        ['e2e4'],
        levelRating: 1100,
        playerSide: Side.white,
        campaignMode: true,
      );
      await games.beginGame(ongoing);
      final completed = ongoing.copyWith(
        status: StoredGameStatus.completed,
        result: StoredGameResult.whiteWin,
        termination: GameTermination.checkmate,
        endedAtUtc: DateTime.utc(2026, 8, 5, 13),
        pgn: const PgnService().export(ongoing),
      );

      expect(await games.completeGame(completed), isTrue);
      expect(await games.completeGame(completed), isFalse);
      final progress = await DriftProgressRepository(database).getAll();
      expect(progress.first.validWins, 1);
      expect(progress.first.gamesInWindow, 1);
      expect(progress[1].unlocked, isFalse);
      expect(await database.select(database.ratingHistory).get(), hasLength(1));
      expect(
        (await games.getGame('campaign'))!.status,
        StoredGameStatus.completed,
      );
    });

    test('partida não avaliada não incrementa campanha', () async {
      final ongoing = _ongoingGame(
        'not-evaluated',
        ['e2e4'],
        levelRating: 1100,
        playerSide: Side.white,
        campaignMode: true,
        evaluated: false,
      );
      await games.beginGame(ongoing);
      await games.completeGame(
        ongoing.copyWith(
          status: StoredGameStatus.completed,
          result: StoredGameResult.whiteWin,
          termination: GameTermination.checkmate,
          endedAtUtc: DateTime.utc(2026, 8, 5, 13),
        ),
      );

      final progress = await DriftProgressRepository(database).getAll();
      expect(progress.first.validWins, 0);
      expect(await database.select(database.ratingHistory).get(), isEmpty);
    });

    test(
      'rating e resultados usam somente partidas avaliadas contra IA',
      () async {
        await _complete(
          games,
          _ongoingGame(
            'a-win',
            ['e2e4'],
            levelRating: 1100,
            playerSide: Side.white,
          ),
          result: StoredGameResult.whiteWin,
          endedAtUtc: DateTime.utc(2026, 8, 5, 13),
        );
        await _complete(
          games,
          _ongoingGame(
            'b-loss',
            ['d2d4'],
            levelRating: 1100,
            playerSide: Side.black,
          ),
          result: StoredGameResult.whiteWin,
          endedAtUtc: DateTime.utc(2026, 8, 5, 14),
        );
        await _complete(
          games,
          _ongoingGame(
            'c-draw',
            ['c2c4'],
            levelRating: 1500,
            playerSide: Side.white,
          ),
          result: StoredGameResult.draw,
          endedAtUtc: DateTime.utc(2026, 8, 5, 15),
        );
        await _complete(
          games,
          _ongoingGame(
            'd-hint',
            ['g1f3'],
            levelRating: 1900,
            playerSide: Side.white,
            evaluated: false,
          ),
          result: StoredGameResult.whiteWin,
          endedAtUtc: DateTime.utc(2026, 8, 5, 16),
        );
        await _complete(
          games,
          _ongoingGame('e-local', ['e2e4']),
          result: StoredGameResult.whiteWin,
          endedAtUtc: DateTime.utc(2026, 8, 5, 17),
        );

        final stats = await DriftStatsRepository(database).get();
        expect(stats.evaluatedGames, 3);
        expect(stats.ratingHistory, hasLength(3));
        expect(stats.resultsByLevel[1100]?.wins, 1);
        expect(stats.resultsByLevel[1100]?.losses, 1);
        expect(stats.resultsByLevel[1500]?.draws, 1);
        expect(stats.resultsByLevel[1900], isNull);
        expect(stats.currentStreak, 0);
        expect(stats.recordStreak, 1);
        expect(
          stats.estimatedRating,
          closeTo(stats.ratingHistory.last.value, 0.000001),
        );
      },
    );

    test('campanha desbloqueia com 2 de 3 e não regride depois', () async {
      await _campaignResult(
        games,
        id: 'campaign-1-win',
        result: StoredGameResult.whiteWin,
        hour: 13,
      );
      var progress = await DriftProgressRepository(database).getAll();
      expect(progress.first.validWins, 1);
      expect(progress.first.gamesInWindow, 1);
      expect(progress[1].unlocked, isFalse);

      await _campaignResult(
        games,
        id: 'campaign-2-loss',
        result: StoredGameResult.blackWin,
        hour: 14,
      );
      await _campaignResult(
        games,
        id: 'campaign-3-win',
        result: StoredGameResult.whiteWin,
        hour: 15,
      );
      progress = await DriftProgressRepository(database).getAll();
      expect(progress.first.validWins, 2);
      expect(progress.first.gamesInWindow, 3);
      expect(progress.first.levelCompleted, isTrue);
      expect(progress[1].unlocked, isTrue);

      await _campaignResult(
        games,
        id: 'campaign-4-loss',
        result: StoredGameResult.blackWin,
        hour: 16,
      );
      progress = await DriftProgressRepository(database).getAll();
      expect(progress.first.levelCompleted, isTrue);
      expect(progress[1].unlocked, isTrue);
    });

    test('exclusão reconstrói rating, placar e desbloqueios', () async {
      await _campaignResult(
        games,
        id: 'rebuild-a-win',
        result: StoredGameResult.whiteWin,
        hour: 13,
      );
      await _campaignResult(
        games,
        id: 'rebuild-b-loss',
        result: StoredGameResult.blackWin,
        hour: 14,
      );
      await _campaignResult(
        games,
        id: 'rebuild-c-win',
        result: StoredGameResult.whiteWin,
        hour: 15,
      );
      expect(
        (await DriftProgressRepository(database).getAll())[1].unlocked,
        isTrue,
      );

      await games.deleteGame('rebuild-c-win');

      final stats = await DriftStatsRepository(database).get();
      final progress = await DriftProgressRepository(database).getAll();
      final history = await database.select(database.ratingHistory).get();
      final expected = const PlayerStatsCalculator().calculate([
        EvaluatedGameSummary(
          gameId: 'rebuild-a-win',
          completedAtUtc: DateTime.utc(2026, 8, 5, 13),
          levelRating: 1100,
          outcome: PlayerGameOutcome.win,
          campaignMode: true,
        ),
        EvaluatedGameSummary(
          gameId: 'rebuild-b-loss',
          completedAtUtc: DateTime.utc(2026, 8, 5, 14),
          levelRating: 1100,
          outcome: PlayerGameOutcome.loss,
          campaignMode: true,
        ),
      ]);

      expect(stats.evaluatedGames, 2);
      expect(stats.resultsByLevel[1100]?.wins, 1);
      expect(stats.resultsByLevel[1100]?.losses, 1);
      expect(
        stats.estimatedRating,
        closeTo(expected.estimatedRating, 0.000001),
      );
      expect(history, hasLength(2));
      expect(progress.first.validWins, 1);
      expect(progress.first.gamesInWindow, 2);
      expect(progress[1].unlocked, isFalse);
    });

    test('configurações são tipadas e persistidas', () async {
      final repository = DriftSettingsRepository(database);
      const settings = StoredAppSettings(
        themeMode: StoredThemeMode.dark,
        defaultClockEnabled: true,
        defaultTimeMinutes: 15,
      );
      await repository.save(settings);

      final restored = await repository.get();
      expect(restored.themeMode, StoredThemeMode.dark);
      expect(restored.defaultClockEnabled, isTrue);
      expect(restored.defaultTimeMinutes, 15);
    });
  });

  group('PGN', () {
    test('importa comentários e tags desconhecidas e valida os lances', () {
      const source = '''
[Event "Teste"]
[X-Custom "preservada"]
[Result "*"]

1. e4 {comentário livre} e5 2. Nf3 (2. Bc4 Nc6) Nc6 *
''';
      final imported = const PgnService().parseImport(
        pgn: source,
        id: 'pgn',
        importedAtUtc: DateTime.utc(2026, 8, 5),
      );

      expect(imported.moves.map((move) => move.uci), [
        'e2e4',
        'e7e5',
        'g1f3',
        'b8c6',
      ]);
      expect(imported.pgn, contains('[X-Custom "preservada"]'));
      expect(imported.pgn, contains('comentário livre'));
      expect(imported.evaluated, isFalse);
      expect(const GameReplayer().replay(imported).positions, hasLength(5));
    });

    test('rejeita PGN ilegal sem gravar parcialmente', () async {
      expect(
        () => const PgnService().parseImport(
          pgn: '1. e4 e5 2. Bh6 *',
          id: 'invalid',
          importedAtUtc: DateTime.utc(2026, 8, 5),
        ),
        throwsA(isA<PgnFormatException>()),
      );
      expect(await games.watchLibrary().first, isEmpty);
    });

    test('rejeita texto de lance ignorado pelo parser dentro de variante', () {
      expect(
        () => const PgnService().parseImport(
          pgn: '1. e4 e5 2. Nf3 (2. Bc4 lixo Nc6) Nc6 *',
          id: 'invalid-variation',
          importedAtUtc: DateTime.utc(2026, 8, 5),
        ),
        throwsA(
          isA<PgnFormatException>().having(
            (error) => error.message,
            'message',
            contains('variante'),
          ),
        ),
      );
    });

    test('PGN exportado pode ser importado com a mesma sequência', () {
      final original = _ongoingGame(
        'roundtrip',
        ['e2e4', 'e7e5', 'g1f3', 'b8c6'],
        levelRating: 1500,
        playerSide: Side.white,
      );
      final exported = const PgnService().export(original);
      final imported = const PgnService().parseImport(
        pgn: exported,
        id: 'roundtrip-import',
        importedAtUtc: DateTime.utc(2026, 8, 5),
      );

      expect(
        imported.moves.map((move) => move.uci),
        original.moves.map((move) => move.uci),
      );
      expect(imported.currentFen, original.currentFen);
    });
  });
}

Future<void> _complete(
  DriftGameRepository repository,
  StoredGame ongoing, {
  required StoredGameResult result,
  required DateTime endedAtUtc,
}) async {
  await repository.beginGame(ongoing);
  await repository.completeGame(
    ongoing.copyWith(
      status: StoredGameStatus.completed,
      result: result,
      termination: GameTermination.unknown,
      endedAtUtc: endedAtUtc,
      lastModifiedAtUtc: endedAtUtc,
    ),
  );
}

Future<void> _campaignResult(
  DriftGameRepository repository, {
  required String id,
  required StoredGameResult result,
  required int hour,
}) {
  return _complete(
    repository,
    _ongoingGame(
      id,
      const [],
      levelRating: 1100,
      playerSide: Side.white,
      campaignMode: true,
    ),
    result: result,
    endedAtUtc: DateTime.utc(2026, 8, 5, hour),
  );
}

StoredGame _ongoingGame(
  String id,
  List<String> ucis, {
  int? levelRating,
  Side? playerSide,
  bool campaignMode = false,
  bool evaluated = true,
}) {
  var position = Chess.initial;
  final now = DateTime.utc(2026, 8, 5, 12);
  final moves = <StoredGameMove>[];
  for (var index = 0; index < ucis.length; index++) {
    final move = Move.parse(ucis[index])!;
    final (after, san) = position.makeSan(move);
    position = after as Chess;
    moves.add(
      StoredGameMove(
        ply: index + 1,
        uci: move.uci,
        san: san,
        fenAfter: position.fen,
        actor: levelRating == null
            ? GameMoveActor.player
            : index.isEven
            ? GameMoveActor.player
            : GameMoveActor.maia,
        playedAtUtc: now.add(Duration(seconds: index)),
      ),
    );
  }
  return StoredGame(
    id: id,
    startedAtUtc: now,
    lastModifiedAtUtc: now,
    status: StoredGameStatus.ongoing,
    levelRating: levelRating,
    playerSide: playerSide,
    result: StoredGameResult.ongoing,
    evaluated: evaluated,
    campaignMode: campaignMode,
    initialFen: Chess.initial.fen,
    currentFen: position.fen,
    moves: moves,
  );
}
