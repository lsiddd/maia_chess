import 'dart:async';
import 'dart:isolate';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_service.dart';
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

void main() {
  for (final phase in ['port', 'startup', 'close', 'run', 'late-close']) {
    test('shutdown is bounded when the worker stalls during $phase', () async {
      final handles = <_RunOptions>[];
      final service = MaiaService(
        worker: _worker,
        shutdownTimeout: const Duration(milliseconds: 200),
        runOptionsFromAddress: (_) {
          final handle = _RunOptions();
          handles.add(handle);
          return handle;
        },
      );
      final starting = service.init(phase);
      Future<void>? cancelledStartup;
      if (phase == 'port' || phase == 'startup') {
        cancelledStartup = expectLater(starting, throwsStateError);
      } else {
        await starting;
      }
      Future<void>? cancelledRun;
      if (phase == 'run') {
        cancelledRun = expectLater(
          service.policy([Chess.initial], selfElo: 1100, opponentElo: 1100),
          throwsStateError,
        );
      }
      final closing = service.dispose();
      final secondClosing = service.dispose();
      final shutdownFailure = throwsA(
        isA<TimeoutException>().having(
          (error) => error.message,
          'message',
          contains('Maia-3 shutdown'),
        ),
      );
      await Future.wait([
        expectLater(
          closing.timeout(const Duration(seconds: 1)),
          shutdownFailure,
        ),
        expectLater(
          secondClosing.timeout(const Duration(seconds: 1)),
          shutdownFailure,
        ),
      ]);
      await cancelledStartup;
      await cancelledRun;
      expect(service.isReady, isFalse);
      expect(handles.every((handle) => handle.cancellations == 1), isTrue);

      // The same service can create a fresh worker after the failed cleanup.
      await service.init('healthy');
      if (phase == 'late-close') {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      expect(service.isReady, isTrue);
      final policy = await service.policy(
        [Chess.initial],
        selfElo: 1100,
        opponentElo: 1100,
      );
      expect(policy, [0.5]);
      await service.dispose();
      expect(service.isReady, isFalse);
    });
  }

  test('failed startup can be disposed without masking its error', () async {
    final service = MaiaService(
      worker: _worker,
      runOptionsFromAddress: (_) => _RunOptions(),
    );
    await expectLater(service.init('error'), throwsStateError);
    await service.dispose();
    await service.init('healthy');
    expect(service.isReady, isTrue);
    await service.dispose();
  });

  test('startup queued during shutdown still shares a single worker', () async {
    var handles = 0;
    final service = MaiaService(
      worker: _worker,
      runOptionsFromAddress: (_) {
        handles++;
        return _RunOptions();
      },
    );
    await service.init('drain');
    final closing = service.dispose();
    final restarting = service.init('healthy');
    await closing;
    final duplicate = service.init('healthy');
    await Future.wait([
      restarting,
      duplicate,
    ]).timeout(const Duration(seconds: 1));
    expect(handles, 2);
    expect(service.isReady, isTrue);
    await service.dispose();
  });
}

class _RunOptions extends Fake implements OrtRunOptions {
  int cancellations = 0;
  @override
  void setTerminate() => cancellations++;
  @override
  void unsetTerminate() {}
}

void _worker((SendPort, String) arguments) async {
  final (reply, phase) = arguments;
  final commands = ReceivePort();
  // The finite delay also lets failed pre-fix tests clean up their workers.
  final expiry = Timer(const Duration(seconds: 2), commands.close);
  if (phase != 'port') reply.send(commands.sendPort);
  await for (final raw in commands) {
    final message = raw as List;
    if (message[1] == 'init') {
      if (phase == 'error') {
        reply.send([0, null, 'model invalid']);
        break;
      }
      if (phase != 'startup') {
        reply.send([
          0,
          [commands.sendPort, 1],
          null,
        ]);
      }
      continue;
    }
    if (message[1] == 'close' && phase == 'healthy') {
      reply.send([message[0], null, null]);
      break;
    }
    if (message[1] == 'close' && phase == 'drain') {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      reply.send([message[0], null, null]);
      break;
    }
    if (message[1] == 'close' && phase == 'late-close') {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      reply.send([message[0], null, null]);
      break;
    }
    if (message[1] == 'run' && phase == 'healthy') {
      reply.send([
        message[0],
        [0.5],
        null,
      ]);
    }
  }
  expiry.cancel();
  commands.close();
}
