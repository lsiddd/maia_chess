import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartchess/dartchess.dart';
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

import 'maia_encoding.dart';

typedef _InferenceRequest = ({
  Float32List tokens,
  int selfElo,
  int opponentElo,
});

abstract interface class MaiaEngine {
  bool get isReady;
  Future<void> init(String modelPath);
  Future<String> getMove(
    List<Chess> positions, {
    required int selfElo,
    required int opponentElo,
  });
  void cancel();
  Future<void> dispose();
}

/// A single model session on a dedicated Dart isolate. Native tensors never
/// cross isolates; the shared run-options handle is only used for ORT's
/// thread-safe cancellation, and stays alive until shutdown is acknowledged.
class MaiaService implements MaiaEngine {
  MaiaService({Random? random}) : _random = random ?? Random();
  final Random _random;
  ReceivePort? _receive;
  SendPort? _commands;
  OrtRunOptions? _runOptions;
  final _pending = <int, Completer<Object?>>{};
  Future<void>? _startup;
  Future<void>? _disposal;
  Future<Object?>? _running;
  int _nextId = 1;
  int _generation = 0;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init(String modelPath) {
    if (_startup != null) return _startup!;
    if (_ready) return Future.value();
    final generation = ++_generation;
    final startup = _initialize(modelPath, generation);
    _startup = startup;
    return startup.whenComplete(() => _startup = null);
  }

  Future<void> _initialize(String path, int generation) async {
    if (_disposal != null) await _disposal;
    if (generation != _generation) throw StateError('Maia-3 startup cancelled');
    final receive = _receive = ReceivePort();
    final ready = Completer<Object?>();
    _pending[0] = ready;
    receive.listen((message) {
      if (message is List && message.length == 3 && message[0] is int) {
        final pending = _pending.remove(message[0]);
        if (message[2] != null) {
          pending?.completeError(StateError(message[2] as String));
        } else {
          pending?.complete(message[1]);
        }
      } else {
        _ready = false;
        // The worker owns these handles; never signal cancellation through
        // a pointer after its isolate has exited and released native state.
        _runOptions = null;
        _commands = null;
        for (final pending in _pending.values) {
          pending.completeError(StateError('Maia-3 worker stopped: $message'));
        }
        _pending.clear();
      }
    });
    try {
      await Isolate.spawn(
        _maiaWorker,
        (receive.sendPort, path),
        onError: receive.sendPort,
        onExit: receive.sendPort,
      );
      final response = (await ready.future) as List;
      _commands = response[0] as SendPort;
      _runOptions = OrtRunOptions.fromAddress(response[1] as int);
      if (generation != _generation) {
        throw StateError('Maia-3 startup cancelled');
      }
      _ready = true;
    } catch (_) {
      if (_commands == null) {
        receive.close();
        _receive = null;
      }
      rethrow;
    }
  }

  Future<Object?> _request(String operation, [Object? payload]) {
    final port = _commands;
    if (port == null) throw StateError('Maia-3 is not initialized');
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send([id, operation, payload]);
    return completer.future;
  }

  /// Also used by Android parity tests to compare all 4,352 policy logits.
  Future<List<double>> policy(
    List<Chess> positions, {
    required int selfElo,
    required int opponentElo,
  }) async {
    if (!isReady) throw StateError('Maia-3 is not ready');
    if (_running != null) {
      throw StateError('Maia-3 is already calculating a move');
    }
    if (selfElo < 0 ||
        selfElo > 5000 ||
        opponentElo < 0 ||
        opponentElo > 5000) {
      throw ArgumentError('Maia-3 Elo must be between 0 and 5000');
    }
    final tokens = MaiaEncoding.tokens(positions);
    final generation = _generation;
    _runOptions!.unsetTerminate();
    final running = _running = _request('run', (
      tokens: tokens,
      selfElo: selfElo,
      opponentElo: opponentElo,
    ));
    // Register cleanup before awaiting: the next inference can start as soon
    // as this response completes, while a timed-out native call still drains.
    void clearRunning() {
      if (identical(_running, running)) _running = null;
    }

    unawaited(
      running.then<void>(
        (_) => clearRunning(),
        onError: (Object _, StackTrace _) => clearRunning(),
      ),
    );
    final output = await running.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        cancel();
        throw TimeoutException('Maia-3 did not finish within 30 seconds');
      },
    );
    if (generation != _generation) {
      throw StateError('Maia-3 request cancelled');
    }
    return (output as List).cast<double>();
  }

  @override
  Future<String> getMove(
    List<Chess> positions, {
    required int selfElo,
    required int opponentElo,
  }) async {
    if (positions.isEmpty || MaiaEncoding.legalMoves(positions.last).isEmpty) {
      throw StateError('Position has no legal moves');
    }
    final logits = await policy(
      positions,
      selfElo: selfElo,
      opponentElo: opponentElo,
    );
    return MaiaEncoding.sample(logits, positions.last, _random);
  }

  @override
  void cancel() {
    _generation++;
    _runOptions?.setTerminate();
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    cancel();
    _ready = false;
    final disposal = _dispose();
    _disposal = disposal;
    return disposal.whenComplete(() => _disposal = null);
  }

  Future<void> _dispose() async {
    try {
      try {
        await _startup;
      } on Object {
        /* Startup already reports errors. */
      }
      _runOptions = null;
      if (_commands != null) await _request('close');
    } finally {
      _commands = null;
      _receive?.close();
      _receive = null;
    }
  }
}

void _maiaWorker((SendPort, String) arguments) async {
  final (reply, path) = arguments;
  final commands = ReceivePort();
  OrtSession? session;
  OrtRunOptions? run;
  int? closingId;
  try {
    OrtEnv.instance.init();
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    try {
      session = OrtSession.fromFile(io.File(path), options);
    } finally {
      options.release();
    }
    run = OrtRunOptions();
    reply.send([
      0,
      [commands.sendPort, run.address],
      null,
    ]);
    await for (final raw in commands) {
      final message = raw as List;
      final id = message[0] as int;
      if (message[1] == 'close') {
        closingId = id;
        break;
      }
      final inputs = <String, OrtValue>{};
      List<OrtValue?> outputs = [];
      try {
        final request = message[2] as _InferenceRequest;
        inputs['tokens'] = OrtValueTensor.createTensorWithDataList(
          request.tokens,
          [1, 64, 96],
        );
        inputs['self_elo'] = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList([request.selfElo]),
          [1],
        );
        inputs['opponent_elo'] = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList([request.opponentElo]),
          [1],
        );
        outputs = session.run(run, inputs, ['policy']);
        final logits = ((outputs.single!.value as List).single as List)
            .cast<double>();
        reply.send([id, logits, null]);
      } catch (error) {
        reply.send([id, null, error.toString()]);
      } finally {
        for (final value in outputs) {
          value?.release();
        }
        for (final value in inputs.values) {
          value.release();
        }
      }
    }
  } catch (error) {
    reply.send([0, null, error.toString()]);
  } finally {
    run?.release();
    session?.release();
    OrtEnv.instance.release();
    commands.close();
    if (closingId != null) reply.send([closingId, null, null]);
  }
}
