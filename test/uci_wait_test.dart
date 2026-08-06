// Testa as primitivas de espera extraídas de Lc0Service/StockfishService
// (ver AUDITORIA_TECNICA.md, AUD-003) isoladas de qualquer FFI real: são a
// parte genérica (ValueListenable/Stream) responsável pelos dois bugs de
// concorrência já documentados em ADR-001 (corrida no dispose, handshake
// isready/readyok).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/engine_ffi/uci_wait.dart';

void main() {
  group('awaitListenableValue', () {
    test('resolve imediatamente se o predicado já é verdadeiro', () async {
      final state = ValueNotifier<int>(5);
      final waiter = awaitListenableValue(state, predicate: (v) => v == 5);

      expect(await waiter.future, 5);
      waiter.cancel(); // não deve lançar mesmo sem listener registrado
    });

    test('resolve quando o valor muda para satisfazer o predicado', () async {
      final state = ValueNotifier<int>(0);
      final waiter = awaitListenableValue(state, predicate: (v) => v == 3);

      state.value = 1;
      state.value = 2;
      state.value = 3;

      expect(await waiter.future, 3);
      waiter.cancel();
    });

    test(
      'ignora mudanças intermediárias que não satisfazem o predicado',
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

    test('cancel() remove o listener e o future nunca completa', () async {
      final state = ValueNotifier<int>(0);
      final waiter = awaitListenableValue(state, predicate: (v) => v == 3);

      waiter.cancel();
      state.value = 3; // não deve completar o future nem lançar

      final outcome = await waiter.future
          .timeout(const Duration(milliseconds: 20))
          .then<String>((_) => 'completou')
          .catchError((_) => 'timeout');
      expect(outcome, 'timeout');
    });

    test('não completa duas vezes com notificações repetidas', () async {
      final state = ValueNotifier<int>(0);
      final waiter = awaitListenableValue(state, predicate: (v) => v >= 3);
      var completions = 0;
      unawaited(waiter.future.then((_) => completions++));

      state.value = 3;
      state.value = 4; // já satisfaz o predicado de novo, não deve recompletar
      await Future<void>.delayed(Duration.zero);

      expect(completions, 1);
      waiter.cancel();
    });
  });

  group('awaitStdoutLine', () {
    test('resolve com a primeira linha que satisfaz o predicado', () async {
      final controller = StreamController<String>();
      final waiter = awaitStdoutLine(
        stdout: controller.stream,
        predicate: (line) => line.trim() == 'readyok',
        onStreamDone: () => StateError('encerrou antes de responder'),
      );

      controller.add('info string carregando pesos');
      controller.add('readyok');
      controller.add('bestmove e2e4'); // não deveria mais importar

      expect(await waiter.future, 'readyok');
      await waiter.cancel();
      await controller.close();
    });

    test('falha com o erro do stream se ele emitir antes de casar', () async {
      final controller = StreamController<String>();
      final waiter = awaitStdoutLine(
        stdout: controller.stream,
        predicate: (line) => line.trim() == 'readyok',
        onStreamDone: () => StateError('encerrou antes de responder'),
      );

      controller.addError(StateError('pipe quebrado'));

      await expectLater(
        waiter.future,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'pipe quebrado',
          ),
        ),
      );
      await waiter.cancel();
      await controller.close();
    });

    test(
      'falha com onStreamDone() se o stream fechar antes de casar',
      () async {
        final controller = StreamController<String>();
        final waiter = awaitStdoutLine(
          stdout: controller.stream,
          predicate: (line) => line.trim() == 'readyok',
          onStreamDone: () =>
              StateError('lc0 encerrou antes de responder readyok'),
        );

        controller.add('info string ainda carregando');
        await controller.close();

        await expectLater(
          waiter.future,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'lc0 encerrou antes de responder readyok',
            ),
          ),
        );
        await waiter.cancel();
      },
    );

    test(
      'cancel() cancela a subscription (stream deixa de ter ouvinte)',
      () async {
        final controller = StreamController<String>();
        final waiter = awaitStdoutLine(
          stdout: controller.stream,
          predicate: (line) => line == 'nunca vai bater',
          onStreamDone: () => StateError('encerrou'),
        );

        expect(controller.hasListener, isTrue);
        await waiter.cancel();
        expect(controller.hasListener, isFalse);

        await controller.close();
      },
    );

    test('não completa de novo após já ter casado uma linha', () async {
      final controller = StreamController<String>();
      final waiter = awaitStdoutLine(
        stdout: controller.stream,
        predicate: (line) => line.startsWith('bestmove'),
        onStreamDone: () => StateError('encerrou'),
      );

      controller.add('bestmove e2e4');
      expect(await waiter.future, 'bestmove e2e4');

      // Uma segunda linha "bestmove" (ex: resposta atrasada de uma busca
      // anterior) não deve ser possível observar: o consumidor já seguiu
      // em frente com a primeira. Só confirmamos que nada lança.
      controller.add('bestmove d2d4');
      await waiter.cancel();
      await controller.close();
    });
  });
}
