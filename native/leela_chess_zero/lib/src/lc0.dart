import 'dart:async';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'lc0_ffi.dart';
import 'lc0_state.dart';

final _logger = Logger('Lc0');

/// A wrapper for the Leela Chess Zero (lc0) C++ engine.
class Lc0 {
  final Completer<Lc0>? completer;

  final _state = _Lc0State();
  final _stdoutController = StreamController<String>.broadcast();
  final _mainPort = ReceivePort();
  final _stdoutPort = ReceivePort();

  late StreamSubscription _mainSubscription;
  late StreamSubscription _stdoutSubscription;
  bool _cleanedUp = false;

  Lc0._({this.completer, String? weightsPath}) {
    _mainSubscription =
        _mainPort.listen((message) => _cleanUp(message is int ? message : 1));
    _stdoutSubscription = _stdoutPort.listen((message) {
      if (message is String) {
        _logger.finest('The stdout isolate sent $message');
        _stdoutController.sink.add(message);
      } else {
        _logger.fine('The stdout isolate sent $message');
      }
    });

    // Pass weightsPath along with the SendPorts
    compute(
        _spawnIsolates,
        _IsolateParams(
          mainPort: _mainPort.sendPort,
          stdoutPort: _stdoutPort.sendPort,
          weightsPath: weightsPath,
        )).then(
      (success) {
        if (_cleanedUp) return;
        final state = success ? Lc0State.ready : Lc0State.error;
        _logger.fine('The init isolate reported $state');
        if (state == Lc0State.ready) {
          _state._setValue(state);
          completer?.complete(this);
        } else {
          if (completer != null && !completer!.isCompleted) {
            completer!.completeError(StateError('Lc0 failed to initialize'));
          }
          _cleanUp(1);
        }
      },
      onError: (error) {
        _logger.severe('The init isolate encountered an error $error');
        if (completer != null && !completer!.isCompleted) {
          completer!.completeError(error);
        }
        _cleanUp(1);
      },
    );
  }

  static Lc0? _instance;

  /// Creates a C++ engine instance.
  ///
  /// [weightsPath] is the path to the neural network weights file (.pb.gz).
  /// This is required for lc0 to function properly.
  ///
  /// This may throw a [StateError] if an active instance is being used.
  /// Owner must [dispose] it before a new instance can be created.
  factory Lc0({String? weightsPath}) {
    if (_instance != null) {
      throw StateError('Multiple instances are not supported, yet.');
    }

    _instance = Lc0._(weightsPath: weightsPath);
    return _instance!;
  }

  /// The current state of the underlying C++ engine.
  ValueListenable<Lc0State> get state => _state;

  /// The standard output stream.
  Stream<String> get stdout => _stdoutController.stream;

  /// The standard input sink.
  set stdin(String line) {
    final stateValue = _state.value;
    if (stateValue != Lc0State.ready) {
      throw StateError('Lc0 is not ready ($stateValue)');
    }

    final pointer = '$line\n'.toNativeUtf8();
    nativeStdinWrite(pointer);
    calloc.free(pointer);
  }

  /// Stops the C++ engine.
  void dispose() {
    stdin = 'quit';
  }

  void _cleanUp(int exitCode) {
    if (_cleanedUp) return;
    _cleanedUp = true;
    _stdoutController.close();

    _mainSubscription.cancel();
    _stdoutSubscription.cancel();

    _state._setValue(exitCode == 0 ? Lc0State.disposed : Lc0State.error);

    if (identical(_instance, this)) {
      _instance = null;
    }
  }
}

/// Creates a C++ engine asynchronously.
///
/// [weightsPath] is the path to the neural network weights file (.pb.gz).
/// This is required for lc0 to function properly.
///
/// This method is different from the factory method [Lc0.new] that
/// it will wait for the engine to be ready before returning the instance.
Future<Lc0> lc0Async({String? weightsPath}) {
  if (Lc0._instance != null) {
    return Future.error(StateError('Only one instance can be used at a time'));
  }

  final completer = Completer<Lc0>();
  Lc0._instance = Lc0._(completer: completer, weightsPath: weightsPath);
  return completer.future;
}

class _Lc0State extends ChangeNotifier implements ValueListenable<Lc0State> {
  Lc0State _value = Lc0State.starting;

  @override
  Lc0State get value => _value;

  _setValue(Lc0State v) {
    if (v == _value) return;
    _value = v;
    notifyListeners();
  }
}

/// Parameters for spawning isolates - passed to compute() function
class _IsolateParams {
  final SendPort mainPort;
  final SendPort stdoutPort;
  final String? weightsPath;

  _IsolateParams({
    required this.mainPort,
    required this.stdoutPort,
    this.weightsPath,
  });
}

void _isolateMain(SendPort mainPort) {
  final exitCode = nativeMain();
  mainPort.send(exitCode);

  _logger.fine('nativeMain returns $exitCode');
}

void _isolateStdout(SendPort stdoutPort) {
  String previous = '';

  while (true) {
    final pointer = nativeStdoutRead();

    if (pointer.address == 0) {
      _logger.fine('nativeStdoutRead returns NULL');
      return;
    }

    final data = previous + pointer.toDartString();
    final lines = data.split('\n');
    previous = lines.removeLast();
    for (final line in lines) {
      stdoutPort.send(line);
    }
  }
}

Future<bool> _spawnIsolates(_IsolateParams params) async {
  final initResult = nativeInit();
  if (initResult != 0) {
    _logger.severe('initResult=$initResult');
    return false;
  }

  // Set weights path if provided
  if (params.weightsPath != null) {
    final pointer = params.weightsPath!.toNativeUtf8();
    nativeSetWeights(pointer);
    calloc.free(pointer);
    _logger.fine('Set weights path to: ${params.weightsPath}');
  } else {
    _logger.warning('No weights path provided - lc0 may fail to start');
  }

  try {
    await Isolate.spawn(_isolateStdout, params.stdoutPort);
  } catch (error) {
    _logger.severe('Failed to spawn stdout isolate: $error');
    return false;
  }

  try {
    await Isolate.spawn(_isolateMain, params.mainPort);
  } catch (error) {
    _logger.severe('Failed to spawn main isolate: $error');
    return false;
  }

  return true;
}
