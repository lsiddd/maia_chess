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
  bool _bootstrapFinished = false;
  bool _mainExited = false;
  bool _stdoutExited = false;
  bool _disposeRequested = false;
  bool _quitSent = false;
  int _exitCode = 1;

  Lc0._({this.completer, String? weightsPath}) {
    _mainSubscription = _mainPort.listen((message) {
      if (message is int) {
        _exitCode = message;
      } else if (message == null) {
        _mainExited = true;
        _tryCleanUp();
      }
    });
    _stdoutSubscription = _stdoutPort.listen((message) {
      if (message is String) {
        _logger.finest('The stdout isolate sent $message');
        _stdoutController.sink.add(message);
      } else if (message == null) {
        _stdoutExited = true;
        _tryCleanUp();
      }
    });

    unawaited(Future<void>.microtask(() => _start(weightsPath)));
  }

  Future<void> _start(String? weightsPath) async {
    var initialized = false;
    var stdoutStarted = false;
    var mainStarted = false;
    try {
      if (_disposeRequested) return;
      final result = nativeInit();
      if (result != 0) {
        throw StateError('Lc0 pipe initialization failed: $result');
      }
      initialized = true;
      if (weightsPath != null) {
        final pointer = weightsPath.toNativeUtf8();
        try {
          nativeSetWeights(pointer);
        } finally {
          calloc.free(pointer);
        }
      }
      await Isolate.spawn(
        _isolateStdout,
        _stdoutPort.sendPort,
        onExit: _stdoutPort.sendPort,
      );
      stdoutStarted = true;
      if (_disposeRequested) {
        nativeAbortStartup(1);
        return;
      }
      await Isolate.spawn(
        _isolateMain,
        _mainPort.sendPort,
        onExit: _mainPort.sendPort,
      );
      mainStarted = true;
      if (!_mainExited && !_stdoutExited) {
        _state._setValue(Lc0State.ready);
        if (_disposeRequested) {
          _sendQuit();
        } else if (completer != null && !completer!.isCompleted) {
          completer!.complete(this);
        }
      }
    } catch (error, stackTrace) {
      _logger.severe('Lc0 startup failed', error, stackTrace);
      if (initialized && !mainStarted) {
        nativeAbortStartup(stdoutStarted ? 1 : 0);
      }
      if (completer != null && !completer!.isCompleted) {
        completer!.completeError(error, stackTrace);
      }
    } finally {
      if (!mainStarted) _mainExited = true;
      if (!stdoutStarted) _stdoutExited = true;
      _bootstrapFinished = true;
      _tryCleanUp();
    }
  }

  static Lc0? _instance;

  /// Creates a C++ engine instance.
  ///
  /// [weightsPath] is the path to the neural network weights file (.pb.gz).
  /// This is required for lc0 to function properly.
  ///
  /// This may throw a [StateError] if an active instance is being used.
  /// The owner must call [dispose] and wait for a terminal state before
  /// creating another instance.
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
    try {
      if (nativeStdinWrite(pointer) < 0) {
        throw StateError('Could not write a command to Lc0');
      }
    } finally {
      calloc.free(pointer);
    }
  }

  /// Request shutdown by sending `quit`; native cleanup is asynchronous.
  void dispose() {
    if (_cleanedUp || _disposeRequested) return;
    _disposeRequested = true;
    if (_state.value == Lc0State.ready) _sendQuit();
  }

  void _sendQuit() {
    if (_quitSent) return;
    stdin = 'quit';
    _quitSent = true;
  }

  void _tryCleanUp() {
    if (_cleanedUp || !_bootstrapFinished || !_mainExited || !_stdoutExited) {
      return;
    }
    _cleanedUp = true;
    unawaited(_stdoutController.close());
    unawaited(_mainSubscription.cancel());
    unawaited(_stdoutSubscription.cancel());

    if (identical(_instance, this)) {
      _instance = null;
    }
    if (completer != null && !completer!.isCompleted) {
      completer!.completeError(StateError('Lc0 exited during startup'));
    }
    _state._setValue(_exitCode == 0 ? Lc0State.disposed : Lc0State.error);
  }
}

/// Creates a C++ engine asynchronously.
///
/// [weightsPath] is the path to the neural network weights file (.pb.gz).
/// This is required for lc0 to function properly.
///
/// Unlike [Lc0.new], this waits for native bootstrap before returning.
/// Callers must still wait for `isready`/`readyok` before searching with
/// loaded weights.
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

void _isolateMain(SendPort mainPort) {
  var exitCode = 1;
  try {
    exitCode = nativeMain();
  } catch (error, stackTrace) {
    nativeAbortStartup(1);
    _logger.severe('The main isolate failed', error, stackTrace);
  } finally {
    mainPort.send(exitCode);
  }
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

