import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/core/constants/difficulty_levels.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/engine_ffi/lc0_engine/lc0_service.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_service.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';

void main() {
  Future<Role?> noPromotion() async => null;

  group('game rules and state', () {
    test('detects checkmate in Scholar\'s Mate', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      for (final uci in [
        'e2e4',
        'e7e5',
        'd1h5',
        'b8c6',
        'f1c4',
        'g8f6',
        'h5f7',
      ]) {
        final move = NormalMove.fromUci(uci);
        await controller.attemptDragMove(
          move.from,
          move.to,
          onPromotion: noPromotion,
        );
      }

      final state = container.read(gameControllerProvider);
      expect(state.isGameOver, isTrue);
      expect(state.result, GameResult.vitoriaBrancas);
      expect(state.sanHistory.last, 'Qxf7#');
    });

    test('detects stalemate and insufficient material', () {
      final stalemate = _stateFromFen('8/8/8/8/8/1pk5/p7/K7 w - - 0 70');
      expect(stalemate.position.isStalemate, isTrue);
      expect(stalemate.isGameOver, isTrue);
      expect(stalemate.result, GameResult.empate);

      final insufficient = _stateFromFen('8/8/8/8/6k1/2N5/2K5/8 w - - 0 1');
      expect(insufficient.position.isInsufficientMaterial, isTrue);
      expect(insufficient.isGameOver, isTrue);
      expect(insufficient.result, GameResult.empate);
    });

    test('adjudicates a draw by the fifty-move rule', () {
      final state = _stateFromFen('8/8/8/8/8/2k5/6R1/2K5 w - - 100 51');

      expect(state.position.isGameOver, isFalse);
      expect(state.isDrawByFiftyMoveRule, isTrue);
      expect(state.isGameOver, isTrue);
      expect(state.result, GameResult.empate);
    });

    test('adjudicates the third repetition of a position', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      for (final uci in [
        'g1f3',
        'g8f6',
        'f3g1',
        'f6g8',
        'g1f3',
        'g8f6',
        'f3g1',
        'f6g8',
      ]) {
        final move = NormalMove.fromUci(uci);
        await controller.attemptDragMove(
          move.from,
          move.to,
          onPromotion: noPromotion,
        );
      }

      final state = container.read(gameControllerProvider);
      expect(state.isDrawByThreefoldRepetition, isTrue);
      expect(state.result, GameResult.empate);

      // The interface does not accept additional moves after game over.
      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: noPromotion,
      );
      expect(container.read(gameControllerProvider).sanHistory.length, 8);
    });

    test(
      'castling uses the conventional destination and moves king and rook',
      () {
        final state = _stateFromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
        final destinations = state.legalDestinationsFrom(Square.e1).toSet();

        expect(destinations, containsAll([Square.g1, Square.c1]));
        expect(destinations, isNot(contains(Square.h1)));
        expect(destinations, isNot(contains(Square.a1)));

        final (castled, san) = state.position.makeSan(
          const NormalMove(from: Square.e1, to: Square.g1),
        );
        expect(san, 'O-O');
        expect(castled.board.pieceAt(Square.g1)?.role, Role.king);
        expect(castled.board.pieceAt(Square.f1)?.role, Role.rook);
      },
    );

    test('en passant removes the captured pawn', () {
      final state = _stateFromFen('6bk/7b/8/3pP3/8/8/8/Q3K3 w - d6 0 2');
      const move = NormalMove(from: Square.e5, to: Square.d6);

      expect(state.position.isLegal(move), isTrue);
      final (after, san) = state.position.makeSan(move);
      expect(san, startsWith('exd6'));
      expect(after.board.pieceAt(Square.d6)?.role, Role.pawn);
      expect(after.board.pieceAt(Square.d5), isNull);
    });

    test('accepts promotion to queen, rook, bishop, and knight', () {
      final state = _stateFromFen('7k/P7/8/8/8/8/8/7K w - - 0 1');

      for (final role in [Role.queen, Role.rook, Role.bishop, Role.knight]) {
        final move = NormalMove(
          from: Square.a7,
          to: Square.a8,
          promotion: role,
        );
        expect(state.position.isLegal(move), isTrue, reason: '$role');
        final (after, _) = state.position.makeSan(move);
        expect(after.board.pieceAt(Square.a8)?.role, role);
      }
    });

    test('silently ignores an illegal move', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      await controller.attemptDragMove(
        Square.b1,
        Square.b3,
        onPromotion: noPromotion,
      );

      final state = container.read(gameControllerProvider);
      expect(state.sanHistory, isEmpty);
      expect(state.position, Chess.initial);
    });
  });

  group('AI game flow with injected engines', () {
    test(
      'undo takes back the human and AI pair and sets evaluated=false',
      () async {
        final maia = FakeLc0Engine(onMove: (_, _) async => 'e7e5');
        final container = _engineContainer(lc0Factory: () => maia);
        addTearDown(() async {
          await container
              .read(gameControllerProvider.notifier)
              .shutdownEngines();
          container.dispose();
        });
        final controller = container.read(gameControllerProvider.notifier);

        expect(
          await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
          isTrue,
        );
        await controller.attemptDragMove(
          Square.e2,
          Square.e4,
          onPromotion: noPromotion,
        );
        expect(container.read(gameControllerProvider).sanHistory, ['e4', 'e5']);

        await controller.undo();
        final afterUndo = container.read(gameControllerProvider);
        final persisted = await container
            .read(gameRepositoryProvider)
            .getActiveGame();
        expect(afterUndo.aiSide, Side.black);
        expect(afterUndo.position, Chess.initial);
        expect(afterUndo.sanHistory, isEmpty);
        expect(afterUndo.evaluated, isFalse);
        expect(persisted!.moves, isEmpty);
        expect(persisted.evaluated, isFalse);
      },
    );

    test(
      'a player choosing Black receives the automatic opening Maia move',
      () async {
        final maia = FakeLc0Engine(onMove: (_, _) async => 'e2e4');
        final container = _engineContainer(lc0Factory: () => maia);
        addTearDown(() async {
          await container
              .read(gameControllerProvider.notifier)
              .shutdownEngines();
          container.dispose();
        });
        final controller = container.read(gameControllerProvider.notifier);

        final started = await controller.startVsAi(
          humanSide: Side.black,
          levelRating: 1100,
        );
        final state = container.read(gameControllerProvider);

        expect(started, isTrue);
        expect(state.aiSide, Side.white);
        expect(state.sanHistory, ['e4']);
        expect(state.position.turn, Side.black);
        expect(maia.requestedFens, hasLength(1));
        expect(state.canUndo, isFalse);

        await controller.undo();
        expect(container.read(gameControllerProvider).sanHistory, ['e4']);
      },
    );

    test('campaign mode is preserved in state and autosave', () async {
      final repository = FakeGameRepository();
      final container = _engineContainer(
        lc0Factory: () => FakeLc0Engine(onMove: (_, _) async => 'e2e4'),
        repository: repository,
      );
      addTearDown(() async {
        await container.read(gameControllerProvider.notifier).shutdownEngines();
        container.dispose();
      });

      expect(
        await container
            .read(gameControllerProvider.notifier)
            .startVsAi(
              humanSide: Side.white,
              levelRating: 1100,
              campaignMode: true,
            ),
        isTrue,
      );

      expect(container.read(gameControllerProvider).campaignMode, isTrue);
      expect((await repository.getActiveGame())?.campaignMode, isTrue);
    });

    test(
      'resume replays autosave without duplicating the automatic opening',
      () async {
        final repository = FakeGameRepository();
        final firstMaia = FakeLc0Engine(onMove: (_, _) async => 'e2e4');
        final firstContainer = _engineContainer(
          lc0Factory: () => firstMaia,
          repository: repository,
        );
        final firstController = firstContainer.read(
          gameControllerProvider.notifier,
        );
        expect(
          await firstController.startVsAi(
            humanSide: Side.black,
            levelRating: 1100,
          ),
          isTrue,
        );
        await firstController.shutdownEngines();
        firstContainer.dispose();

        final restoredMaia = FakeLc0Engine(onMove: (_, _) async => 'd2d4');
        final restoredContainer = _engineContainer(
          lc0Factory: () => restoredMaia,
          repository: repository,
        );
        addTearDown(() async {
          await restoredContainer
              .read(gameControllerProvider.notifier)
              .shutdownEngines();
          restoredContainer.dispose();
        });

        expect(
          await restoredContainer
              .read(gameControllerProvider.notifier)
              .restoreActiveGame(),
          isTrue,
        );
        final restored = restoredContainer.read(gameControllerProvider);
        expect(restored.sanHistory, ['e4']);
        expect(restored.position.turn, Side.black);
        expect(restoredMaia.requestedFens, isEmpty);
      },
    );

    test(
      'autosave read failure is exposed without breaking the controller',
      () async {
        final repository = FakeGameRepository(
          activeError: StateError('database unavailable'),
        );
        final container = _engineContainer(
          lc0Factory: () => FakeLc0Engine(onMove: (_, _) async => 'e2e4'),
          repository: repository,
        );
        addTearDown(container.dispose);

        final restored = await container
            .read(gameControllerProvider.notifier)
            .restoreActiveGame();
        final state = container.read(gameControllerProvider);

        expect(restored, isFalse);
        expect(state.persistenceError, contains('database unavailable'));
        expect(state.position, Chess.initial);
      },
    );

    test(
      'switching 1100 -> 1900 -> 1100 disposes and recreates Maia',
      () async {
        final engines = <FakeLc0Engine>[];
        final container = _engineContainer(
          lc0Factory: () {
            final engine = FakeLc0Engine(onMove: (_, _) async => 'e2e4');
            engines.add(engine);
            return engine;
          },
        );
        addTearDown(() async {
          await container
              .read(gameControllerProvider.notifier)
              .shutdownEngines();
          container.dispose();
        });
        final controller = container.read(gameControllerProvider.notifier);

        for (final rating in [1100, 1900, 1100]) {
          expect(
            await controller.startVsAi(
              humanSide: Side.white,
              levelRating: rating,
            ),
            isTrue,
          );
        }

        expect(engines, hasLength(3));
        expect(engines[0].disposeCount, 1);
        expect(engines[1].disposeCount, 1);
        expect(engines.map((engine) => engine.initPaths.single), [
          'assets/maia_weights/maia-1100.pb.gz',
          'assets/maia_weights/maia-1900.pb.gz',
          'assets/maia_weights/maia-1100.pb.gz',
        ]);
      },
    );

    test(
      'a new game cancels the old search without applying a delayed response',
      () async {
        final oldMove = Completer<String>();
        final engines = <FakeLc0Engine>[];
        final container = _engineContainer(
          lc0Factory: () {
            final isFirst = engines.isEmpty;
            final engine = FakeLc0Engine(
              onMove: (_, _) => isFirst ? oldMove.future : Future.value('e2e4'),
            );
            engines.add(engine);
            return engine;
          },
        );
        addTearDown(() async {
          await container
              .read(gameControllerProvider.notifier)
              .shutdownEngines();
          container.dispose();
        });
        final controller = container.read(gameControllerProvider.notifier);

        final oldGame = controller.startVsAi(
          humanSide: Side.black,
          levelRating: 1100,
        );
        while (engines.isEmpty || engines.first.requestedFens.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(
          await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
          isTrue,
        );
        oldMove.complete('e2e4');
        expect(await oldGame, isFalse);

        final current = container.read(gameControllerProvider);
        expect(engines, hasLength(2));
        expect(engines.first.disposeCount, 1);
        expect(current.aiSide, Side.black);
        expect(current.sanHistory, isEmpty);
        expect(current.position, Chess.initial);
      },
    );

    test('engine startup failure allows a later retry', () async {
      final engines = <FakeLc0Engine>[];
      final container = _engineContainer(
        lc0Factory: () {
          final engine = FakeLc0Engine(
            initError: engines.isEmpty ? StateError('native failure') : null,
            onMove: (_, _) async => 'e2e4',
          );
          engines.add(engine);
          return engine;
        },
      );
      addTearDown(() async {
        await container.read(gameControllerProvider.notifier).shutdownEngines();
        container.dispose();
      });
      final controller = container.read(gameControllerProvider.notifier);

      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
        isFalse,
      );
      expect(
        container.read(gameControllerProvider).engineError,
        contains('native failure'),
      );
      expect(engines.first.disposeCount, 1);

      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
        isTrue,
      );
      expect(container.read(gameControllerProvider).engineError, isNull);
      expect(engines, hasLength(2));
    });
  });

  group('DifficultyLevel', () {
    test('has exactly 9 levels, from 1100 to 1900', () {
      expect(DifficultyLevel.all.length, 9);
      expect(DifficultyLevel.all.first.rating, 1100);
      expect(DifficultyLevel.all.last.rating, 1900);
    });

    test('byRating finds the correct level and asset', () {
      final level = DifficultyLevel.byRating(1500);
      expect(level.weightsAsset, 'assets/maia_weights/maia-1500.pb.gz');
    });
  });
}

GameState _stateFromFen(String fen) => GameState(
  position: Chess.fromSetup(Setup.parseFen(fen)),
  positionHistory: const [],
  sanHistory: const [],
  uciHistory: const [],
  moveActorHistory: const [],
  moveTimeHistoryUtc: const [],
);

ProviderContainer _engineContainer({
  required Lc0EngineFactory lc0Factory,
  StockfishEngineFactory? stockfishFactory,
  Duration timeout = const Duration(seconds: 2),
  FakeGameRepository? repository,
}) {
  final persistence = repository ?? FakeGameRepository();
  var nextId = 0;
  return ProviderContainer(
    overrides: [
      lc0EngineFactoryProvider.overrideWithValue(lc0Factory),
      stockfishEngineFactoryProvider.overrideWithValue(
        stockfishFactory ??
            () => FakeStockfishEngine(onMove: (_, _) async => 'e2e4'),
      ),
      maiaWeightsResolverProvider.overrideWithValue(
        (level) async => level.weightsAsset,
      ),
      hintTotalTimeoutProvider.overrideWithValue(timeout),
      gameRepositoryProvider.overrideWithValue(persistence),
      gameIdFactoryProvider.overrideWithValue(() => 'game-${nextId++}'),
    ],
  );
}

class FakeGameRepository implements GameRepository {
  FakeGameRepository({this.activeError});

  final Object? activeError;
  final Map<String, StoredGame> games = {};

  @override
  Future<void> beginGame(StoredGame game) async {
    games.removeWhere((_, stored) => stored.status == StoredGameStatus.ongoing);
    games[game.id] = game;
  }

  @override
  Future<bool> completeGame(StoredGame game) async {
    if (games[game.id]?.status == StoredGameStatus.completed) return false;
    games[game.id] = game;
    return true;
  }

  @override
  Future<void> deleteGame(String id) async {
    games.remove(id);
  }

  @override
  Future<StoredGame?> getActiveGame() async {
    if (activeError case final error?) throw error;
    return games.values
        .where((game) => game.status == StoredGameStatus.ongoing)
        .firstOrNull;
  }

  @override
  Future<StoredGame?> getGame(String id) async => games[id];

  @override
  Future<void> importGame(StoredGame game) async {
    games[game.id] = game;
  }

  @override
  Future<void> saveOngoing(StoredGame game) async {
    games[game.id] = game;
  }

  @override
  Stream<StoredGame?> watchActiveGame() => Stream.value(
    games.values
        .where((game) => game.status == StoredGameStatus.ongoing)
        .firstOrNull,
  );

  @override
  Stream<List<StoredGame>> watchLibrary() =>
      Stream.value(games.values.toList(growable: false));
}

class FakeLc0Engine implements Lc0Engine {
  FakeLc0Engine({required this.onMove, this.initError});

  final Future<String> Function(String fen, int nodes) onMove;
  final Object? initError;
  final List<String> initPaths = [];
  final List<String> requestedFens = [];
  int disposeCount = 0;
  bool _ready = false;
  String? _loadedWeightsPath;

  @override
  bool get isReady => _ready;

  @override
  String? get loadedWeightsPath => _loadedWeightsPath;

  @override
  Future<void> init(String weightsFilePath) async {
    initPaths.add(weightsFilePath);
    if (initError != null) throw initError!;
    _loadedWeightsPath = weightsFilePath;
    _ready = true;
  }

  @override
  Future<String> getBestMove(String fen, {int nodes = 1}) {
    requestedFens.add(fen);
    return onMove(fen, nodes);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _ready = false;
    _loadedWeightsPath = null;
  }
}

class FakeStockfishEngine implements StockfishEngine {
  @override
  Future<List<StockfishLine>> getTopMoves(
    String fen, {
    int count = 3,
    int movetimeMs = 1000,
  }) async =>
      throw UnimplementedError('Configure a MultiPV fake for this test.');

  FakeStockfishEngine({required this.onMove, this.initError});

  final Future<String> Function(String fen, int movetimeMs) onMove;
  final Object? initError;
  final List<String> requestedFens = [];
  int disposeCount = 0;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    if (initError != null) throw initError!;
    _ready = true;
  }

  @override
  Future<String> getBestMove(
    String fen, {
    int movetimeMs = StockfishEngine.defaultMovetimeMs,
  }) {
    requestedFens.add(fen);
    return onMove(fen, movetimeMs);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _ready = false;
  }
}
