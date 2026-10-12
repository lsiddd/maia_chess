import 'dart:async';

import 'package:flutter/foundation.dart';

/// Generic waiters shared by lc0 and Stockfish services. Their listenable and
/// stream contracts can be tested without loading native libraries; actual
/// engine startup and shutdown require Android integration tests.

/// Wait until [predicate] matches the current [listenable] value, resolving
/// immediately if it already matches. The caller applies timeouts and must
/// call `cancel` in `finally` to remove the listener after success or
/// failure.
({Future<T> future, void Function() cancel}) awaitListenableValue<T>(
  ValueListenable<T> listenable, {
  required bool Function(T value) predicate,
}) {
  if (predicate(listenable.value)) {
    return (future: Future.value(listenable.value), cancel: () {});
  }
  final completer = Completer<T>();
  void listener() {
    if (predicate(listenable.value) && !completer.isCompleted) {
      completer.complete(listenable.value);
    }
  }

  listenable.addListener(listener);
  return (
    future: completer.future,
    cancel: () => listenable.removeListener(listener),
  );
}

/// Extract the move from `bestmove <uci> [ponder ...]`. Return an empty
/// string if no second token exists; callers treat this as an invalid
/// response.
String parseBestMove(String line) {
  final parts = line.trim().split(RegExp(r'\s+'));
  return parts.length > 1 ? parts[1] : '';
}

/// Wait for a [stdout] line matching [predicate]. Stream errors propagate; a
/// premature close fails with [onStreamDone]. As with [awaitListenableValue],
/// callers apply timeouts and cancel in `finally`.
({Future<String> future, Future<void> Function() cancel}) awaitStdoutLine({
  required Stream<String> stdout,
  required bool Function(String line) predicate,
  required Object Function() onStreamDone,
}) {
  final completer = Completer<String>();
  final subscription = stdout.listen(
    (line) {
      if (predicate(line) && !completer.isCompleted) {
        completer.complete(line);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
    onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(onStreamDone());
      }
    },
  );
  return (future: completer.future, cancel: subscription.cancel);
}
