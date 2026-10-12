import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:leela_chess_zero/lc0.dart';
import 'package:path_provider/path_provider.dart';

import '../uci_wait.dart';

/// High-level lc0 contract for Maia opponent moves. The `leela_chess_zero`
/// package runs the engine in-process through Dart FFI, with UCI I/O on
/// background isolates.
abstract interface class Lc0Engine {
  bool get isReady;
  String? get loadedWeightsPath;

  Future<void> init(String weightsFilePath);
  Future<String> getBestMove(String fen, {int nodes = 1});
  Future<void> dispose();
}

class Lc0Service implements Lc0Engine {
  static const _readyTimeout = Duration(seconds: 120);
  static const _startupTimeout = Duration(seconds: 20);
  static const _stopGracePeriod = Duration(seconds: 2);
  static const _terminateStepTimeout = Duration(seconds: 5);
  static const _searchTimeout = Duration(seconds: 10);

  Lc0? _engine;
  String? _loadedWeightsPath;
  bool _handshakeDone = false;
  bool _searchInProgress = false;

  /// Loaded weights path, or `null` when no engine is active.
  @override
  String? get loadedWeightsPath => _loadedWeightsPath;

  /// True after the `isready`/`readyok` handshake. Native `Lc0State.ready`
  /// only confirms isolate startup, not that weights have finished loading.
  @override
  bool get isReady =>
      _engine != null &&
      _engine!.state.value == Lc0State.ready &&
      _handshakeDone;

  /// Initialise lc0 with the absolute filesystem [weightsFilePath]. Extract
  /// bundled weights with [extractWeightsAsset] first: lc0 cannot read
  /// directly from the APK asset bundle.
  ///
  /// Only one native instance can exist at a time. A level change disposes
  /// the previous instance before starting another.
  @override
  Future<void> init(String weightsFilePath) async {
    if (_engine != null) {
      await dispose();
    }

    _handshakeDone = false;
    final engine = Lc0(weightsPath: weightsFilePath);
    _engine = engine;

    // The waiter also handles an engine that becomes ready before listener
    // registration.
    final startup = awaitListenableValue(
      engine.state,
      predicate: (state) => state == Lc0State.ready || state == Lc0State.error,
    );
    try {
      final state = await startup.future.timeout(
        _startupTimeout,
        onTimeout: () => throw TimeoutException(
          'lc0 did not start within ${_startupTimeout.inSeconds}s',
        ),
      );
      if (state == Lc0State.error) {
        throw StateError('lc0 failed to start');
      }

      // Native ready only confirms isolate startup. Wait for `readyok` after
      // weights load so a queued search does not consume its timeout waiting
      // for initialisation.
      await _waitReadyOk(engine);
      if (!identical(_engine, engine)) {
        throw StateError('lc0 was disposed during startup');
      }
      _loadedWeightsPath = weightsFilePath;
      _handshakeDone = true;
    } catch (_) {
      await _disposeAfterFailure(engine);
      rethrow;
    } finally {
      startup.cancel();
    }
  }

  Future<void> _waitReadyOk(Lc0 engine) async {
    final waiter = awaitStdoutLine(
      stdout: engine.stdout,
      predicate: (line) => line.trim() == 'readyok',
      onStreamDone: () =>
          StateError('lc0 exited before responding with readyok'),
    );
    try {
      engine.stdin = 'isready';
      await waiter.future.timeout(
        _readyTimeout,
        onTimeout: () => throw TimeoutException(
          'lc0 did not respond to isready/readyok within '
          '${_readyTimeout.inSeconds}s (loading weights)',
        ),
      );
    } finally {
      await waiter.cancel();
    }
  }

  /// Return a UCI move for [fen] with a [nodes] search budget. The app uses
  /// one node to select from the Maia policy rather than deepen the search.
  @override
  Future<String> getBestMove(String fen, {int nodes = 1}) async {
    if (!isReady) {
      throw StateError('lc0 is not ready. Call init() first.');
    }
    if (nodes <= 0) {
      throw ArgumentError.value(nodes, 'nodes', 'must be positive');
    }
    if (_searchInProgress) {
      throw StateError('lc0 is already calculating another move');
    }
    final engine = _engine!;
    final waiter = awaitStdoutLine(
      stdout: engine.stdout,
      predicate: (line) => line.startsWith('bestmove'),
      onStreamDone: () => StateError('lc0 exited before returning bestmove'),
    );

    _searchInProgress = true;
    try {
      engine.stdin = 'position fen $fen';
      engine.stdin = 'go nodes $nodes';
      try {
        final line = await waiter.future.timeout(_searchTimeout);
        final move = parseBestMove(line);
        if (move.isEmpty || move == '(none)') {
          throw StateError('lc0 did not return a valid move');
        }
        return move;
      } on TimeoutException {
        // Stop or dispose a delayed search so its orphaned `bestmove` cannot
        // be mistaken for the next response.
        try {
          engine.stdin = 'stop';
          final line = await waiter.future.timeout(_stopGracePeriod);
          final move = parseBestMove(line);
          if (move.isNotEmpty && move != '(none)') return move;
        } on Object {
          // Disposal below is the recovery path.
        }
        await _disposeAfterFailure(engine);
        throw TimeoutException(
          'lc0 did not respond to the search or stop command',
        );
      }
    } finally {
      _searchInProgress = false;
      await waiter.cancel();
    }
  }

  /// Request shutdown and wait for native disposal, within bounded timeouts.
  /// `Lc0.dispose()` only sends `quit`; the package releases its singleton
  /// after the engine loop exits. There is no force-kill API, so a timeout
  /// does not guarantee shutdown.
  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _loadedWeightsPath = null;
    _handshakeDone = false;
    if (engine == null) return;

    await _terminateEngine(engine);
  }

  Future<void> _disposeAfterFailure(Lc0 engine) async {
    if (identical(_engine, engine)) {
      _engine = null;
    }
    _loadedWeightsPath = null;
    _handshakeDone = false;

    await _terminateEngine(engine);
  }

  Future<void> _terminateEngine(Lc0 engine) async {
    var current = engine.state.value;
    if (current == Lc0State.disposed || current == Lc0State.error) return;

    // The wrapper accepts `quit` only when ready. Wait for bootstrap to
    // finish before attempting a clean shutdown.
    if (current == Lc0State.starting) {
      final startup = awaitListenableValue(
        engine.state,
        predicate: (state) => state != Lc0State.starting,
      );
      try {
        current = await startup.future.timeout(_terminateStepTimeout);
      } on TimeoutException {
        return;
      } finally {
        startup.cancel();
      }
    }
    if (current != Lc0State.ready) return;

    final terminated = awaitListenableValue(
      engine.state,
      predicate: (state) =>
          state == Lc0State.disposed || state == Lc0State.error,
    );
    try {
      engine.dispose();
      await terminated.future.timeout(_terminateStepTimeout);
    } on Object {
      // The package has no force-kill API; singleton release depends on the
      // engine loop consuming `quit`.
    } finally {
      terminated.cancel();
    }
  }

  /// Copy bundled `.pb.gz` weights to application support storage and return
  /// the absolute path. Rewrite only when the file is absent or its size
  /// differs from the asset.
  static Future<String> extractWeightsAsset(
    String assetPath, {
    String? fileName,
  }) async {
    final data = await rootBundle.load(assetPath);
    final dir = await getApplicationSupportDirectory();
    final weightsDir = Directory('${dir.path}/maia_weights');
    if (!await weightsDir.exists()) {
      await weightsDir.create(recursive: true);
    }
    final name = fileName ?? assetPath.split('/').last;
    final file = File('${weightsDir.path}/$name');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (!await file.exists() || await file.length() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }
}
