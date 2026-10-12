// Test shared listenable and stream waiters without native FFI, including
// disposal races and UCI readiness responses.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/engine_ffi/uci_wait.dart';

void main() {
  group('awaitListenableValue', () {
    test('resolves immediately when the predicate is already true', () async {
      final state = ValueNotifier<int>(5);
      final waiter = awaitListenableValue(state, predicate: (v) => v == 5);

      expect(await waiter.future, 5);
      waiter.cancel(); // Must not throw even without a registered listener.
    });

    test('resolves when the value changes to satisfy the predicate', () async {
      final state = ValueNotifier<int>(0);
      final waiter = awaitListenableValue(state, predicate: (v) => v == 3);

      state.value = 1;
      state.value = 2;
      state.value = 3;

      expect(await waiter.future, 3);
      waiter.cancel();
    });

    test(
      'ignores intermediate changes that do not satisfy the predicate',
      () async {
        final state = ValueNotifier<int>(0);
        final waiter = awaitListenableValue(state, predicate: (v) => v == 3);
        final seen = <int>[];
        unawaited(waiter.future.then(seen.add));

        state.value = 1;
        state.value = 2;
        await Future<void>.delayed(Duration.zero);
        expect(seen, isEmpty);

        state.value = 3;
        await Future<void>.delayed(Duration.zero);
        expect(seen, [3]);
        waiter.cancel();
      },
    );

    test(
      'cancel() removes the listener and the future never completes',
      () async {
        final state = ValueNotifier<int>(0);
        final waiter = awaitListenableValue(state, predicate: (v) => v == 3);

        waiter.cancel();
        state.value = 3; // Must neither complete the future nor throw.

        final outcome = await waiter.future
            .timeout(const Duration(milliseconds: 20))
            .then<String>((_) => 'completed')
            .catchError((_) => 'timeout');
        expect(outcome, 'timeout');
      },
    );

    test('does not complete twice on repeated notifications', () async {
      final state = ValueNotifier<int>(0);
      final waiter = awaitListenableValue(state, predicate: (v) => v >= 3);
      var completions = 0;
      unawaited(waiter.future.then((_) => completions++));

      state.value = 3;
      state.value =
          4; // Still satisfies the predicate; must not complete again.
      await Future<void>.delayed(Duration.zero);

      expect(completions, 1);
      waiter.cancel();
    });
  });

  group('awaitStdoutLine', () {
    test('resolves with the first line satisfying the predicate', () async {
      final controller = StreamController<String>();
      final waiter = awaitStdoutLine(
        stdout: controller.stream,
        predicate: (line) => line.trim() == 'readyok',
        onStreamDone: () => StateError('exited before responding'),
      );

      controller.add('info string loading weights');
      controller.add('readyok');
      controller.add('bestmove e2e4'); // A later response must have no effect.

      expect(await waiter.future, 'readyok');
      await waiter.cancel();
      await controller.close();
    });

    test('fails with the stream error if emitted before a match', () async {
      final controller = StreamController<String>();
      final waiter = awaitStdoutLine(
        stdout: controller.stream,
        predicate: (line) => line.trim() == 'readyok',
        onStreamDone: () => StateError('exited before responding'),
      );

      controller.addError(StateError('broken pipe'));

      await expectLater(
        waiter.future,
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'broken pipe'),
        ),
      );
      await waiter.cancel();
      await controller.close();
    });

    test(
      'fails with onStreamDone() if the stream closes before a match',
      () async {
        final controller = StreamController<String>();
        final waiter = awaitStdoutLine(
          stdout: controller.stream,
          predicate: (line) => line.trim() == 'readyok',
          onStreamDone: () =>
              StateError('lc0 exited before responding with readyok'),
        );

        controller.add('info string still loading');
        await controller.close();

        await expectLater(
          waiter.future,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'lc0 exited before responding with readyok',
            ),
          ),
        );
        await waiter.cancel();
      },
    );

    test(
      'cancel() cancels the subscription and removes the stream listener',
      () async {
        final controller = StreamController<String>();
        final waiter = awaitStdoutLine(
          stdout: controller.stream,
          predicate: (line) => line == 'will never match',
          onStreamDone: () => StateError('exited'),
        );

        expect(controller.hasListener, isTrue);
        await waiter.cancel();
        expect(controller.hasListener, isFalse);

        await controller.close();
      },
    );

    test('does not complete again after matching a line', () async {
      final controller = StreamController<String>();
      final waiter = awaitStdoutLine(
        stdout: controller.stream,
        predicate: (line) => line.startsWith('bestmove'),
        onStreamDone: () => StateError('exited'),
      );

      controller.add('bestmove e2e4');
      expect(await waiter.future, 'bestmove e2e4');

      // A second bestmove, such as a late response from a previous search,
      // must not complete the future again. Verify that it does not throw.
      controller.add('bestmove d2d4');
      await waiter.cancel();
      await controller.close();
    });
  });
}
