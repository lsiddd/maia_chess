import 'dart:async';
import 'dart:developer' as developer;

import 'package:stockfish/stockfish.dart';

import '../uci_wait.dart';
import 'stockfish_analysis.dart';

/// High-level Stockfish contract for hints and opponent plans, independent of
/// the selected Maia level. The `stockfish` package runs UCI in-process
/// through Dart FFI on background isolates.
abstract interface class StockfishEngine {
  static const defaultMovetimeMs = 500;

  bool get isReady;

  Future<void> init();
  Future<String> getBestMove(String fen, {int movetimeMs = defaultMovetimeMs});
  Future<List<StockfishLine>> getTopMoves(
    String fen, {
    int count = 3,
    int movetimeMs = 1000,
  });
  Future<void> dispose();
}

class StockfishService implements StockfishEngine {
  static const _startupTimeout = Duration(seconds: 20);
  static const _readyTimeout = Duration(seconds: 60);
  static const _stopGracePeriod = Duration(seconds: 2);
  static const _terminateStepTimeout = Duration(seconds: 5);

  Stockfish? _engine;
  bool _handshakeDone = false;
  bool _searchInProgress = false;

  /// True after the `isready`/`readyok` handshake, rather than merely native
  /// isolate startup.
  @override
  bool get isReady =>
      _engine != null &&
      _engine!.state.value == StockfishState.ready &&
      _handshakeDone;

  /// Initialise Stockfish. Its NNUE evaluation network is embedded in the
  /// compiled binary, so no weights path is needed.
  @override
  Future<void> init() async {
    if (_engine != null) {
      await dispose();
    }

    _handshakeDone = false;
    developer.log('Creating engine', name: 'StockfishService');
    final engine = Stockfish();
    _engine = engine;

    final startup = awaitListenableValue(
      engine.state,
      predicate: (state) =>
          state == StockfishState.ready || state == StockfishState.error,
    );
    try {
      final state = await startup.future.timeout(
        _startupTimeout,
        onTimeout: () =>
            throw TimeoutException('Stockfish did not start in time'),
      );
      developer.log('Native state: $state', name: 'StockfishService');
      if (state == StockfishState.error) {
        throw StateError('Stockfish failed to start');
      }

      // Native ready does not confirm NNUE loading. Wait for the UCI
      // handshake before allowing searches.
      developer.log('Sending isready', name: 'StockfishService');
      await _waitReadyOk(engine);
      if (!identical(_engine, engine)) {
        throw StateError('Stockfish was disposed during startup');
      }
      _handshakeDone = true;
      developer.log('readyok handshake completed', name: 'StockfishService');
    } catch (error, stackTrace) {
      developer.log(
        'Startup failed',
        name: 'StockfishService',
        error: error,
        stackTrace: stackTrace,
      );
      await _disposeAfterFailure(engine);
      rethrow;
    } finally {
      startup.cancel();
    }
  }

  Future<void> _waitReadyOk(Stockfish engine) async {
    final waiter = awaitStdoutLine(
      stdout: engine.stdout,
      predicate: (line) => line.trim() == 'readyok',
      onStreamDone: () =>
          StateError('Stockfish exited before responding with readyok'),
    );
    try {
      engine.stdin = 'isready';
      await waiter.future.timeout(
        _readyTimeout,
        onTimeout: () => throw TimeoutException(
          'Stockfish did not respond to isready/readyok within '
          '${_readyTimeout.inSeconds}s',
        ),
      );
    } finally {
      await waiter.cancel();
    }
  }

  /// Return a UCI move for [fen] using a [movetimeMs] search budget. The
  /// default is 500 ms; callers may request a longer search.
  @override
  Future<String> getBestMove(
    String fen, {
    int movetimeMs = StockfishEngine.defaultMovetimeMs,
  }) async {
    return (await _search(fen, movetimeMs: movetimeMs)).bestMove;
  }

  @override
  Future<List<StockfishLine>> getTopMoves(
    String fen, {
    int count = 3,
    int movetimeMs = 1000,
  }) async {
    if (count < 1 || count > 3) {
      throw ArgumentError.value(count, 'count', 'must be between 1 and 3');
    }
    return (await _search(fen, movetimeMs: movetimeMs, count: count)).lines;
  }

  Future<({String bestMove, List<StockfishLine> lines})> _search(
    String fen, {
    required int movetimeMs,
    int count = 1,
  }) async {
    if (!isReady) {
      throw StateError('Stockfish is not ready. Call init() first.');
    }
    if (movetimeMs <= 0) {
      throw ArgumentError.value(movetimeMs, 'movetimeMs', 'must be positive');
    }
    if (_searchInProgress) {
      throw StateError('Stockfish is already calculating another move');
    }

    final engine = _engine!;
    final analysis = StockfishAnalysisCollector(count);
    final waiter = awaitStdoutLine(
      stdout: engine.stdout,
      predicate: (line) {
        analysis.add(line);
        return line.startsWith('bestmove');
      },
      onStreamDone: () =>
          StateError('Stockfish exited before returning bestmove'),
    );

    _searchInProgress = true;
    try {
      developer.log(
        'Starting search movetime=${movetimeMs}ms',
        name: 'StockfishService',
      );
      engine.stdin = 'setoption name MultiPV value $count';
      engine.stdin = 'position fen $fen';
      engine.stdin = 'go movetime $movetimeMs';

      try {
        final line = await waiter.future.timeout(
          Duration(milliseconds: movetimeMs + 8000),
        );
        final move = parseBestMove(line);
        if (move.isEmpty || move == '(none)') {
          throw StateError('Stockfish did not return a valid move');
        }
        developer.log('Received bestmove: $move', name: 'StockfishService');
        return (bestMove: move, lines: analysis.lines);
      } on TimeoutException {
        // Stop a delayed search so an orphaned `bestmove` cannot contaminate
        // the next request.
        developer.log(
          'Search timed out; sending stop',
          name: 'StockfishService',
        );
        try {
          engine.stdin = 'stop';
          final line = await waiter.future.timeout(_stopGracePeriod);
          final move = parseBestMove(line);
          if (move.isNotEmpty && move != '(none)') {
            return (bestMove: move, lines: analysis.lines);
          }
        } on Object {
          // Disposal below is the recovery path.
        }
        await _disposeAfterFailure(engine);
        throw TimeoutException(
          'Stockfish did not respond to the search or stop command',
        );
      }
    } finally {
      // Every search also sets its own value, so hints remain single-PV.
      if (identical(_engine, engine) && isReady) {
        engine.stdin = 'setoption name MultiPV value 1';
      }
      _searchInProgress = false;
      await waiter.cancel();
    }
  }

  /// Request shutdown and wait for singleton release within bounded timeouts.
  /// Shutdown is best effort: the package has no force-kill API, and a later
  /// [init] can still fail if the native loop has not exited.
  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _handshakeDone = false;
    if (engine == null) return;

    await _terminateEngine(engine);
  }

  Future<void> _disposeAfterFailure(Stockfish engine) async {
    if (identical(_engine, engine)) {
      _engine = null;
    }
    _handshakeDone = false;

    await _terminateEngine(engine);
  }

  Future<void> _terminateEngine(Stockfish engine) async {
    var state = engine.state.value;
    if (state == StockfishState.disposed || state == StockfishState.error) {
      return;
    }

    // `Stockfish.dispose()` writes `quit` and throws while the wrapper is
    // still starting. Wait for that transition so cleanup after a startup
    // timeout does not itself fail.
    if (state == StockfishState.starting) {
      final startup = awaitListenableValue(
        engine.state,
        predicate: (value) => value != StockfishState.starting,
      );
      try {
        state = await startup.future.timeout(_terminateStepTimeout);
      } on TimeoutException {
        return;
      } finally {
        startup.cancel();
      }
    }
    if (state != StockfishState.ready) return;

    final terminated = awaitListenableValue(
      engine.state,
      predicate: (value) =>
          value == StockfishState.disposed || value == StockfishState.error,
    );
    try {
      engine.dispose();
      await terminated.future.timeout(_terminateStepTimeout);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not shut down the engine after failure',
        name: 'StockfishService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      terminated.cancel();
    }
  }
}
