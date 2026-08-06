import 'dart:async';

import 'package:flutter/foundation.dart';

/// Primitivas de espera extraídas de `Lc0Service`/`StockfishService` (ver
/// AUDITORIA_TECNICA.md, AUD-003).
///
/// `Lc0` e `Stockfish` (os wrappers FFI dos pacotes de terceiros) são
/// classes concretas com construtor singleton, sem interface em comum:
/// não dá para substituí-las por um fake sem reescrever os pacotes
/// vendorizados/de terceiros, o que iria contra a decisão de manter o
/// `leela_chess_zero` alinhável com o pacote publicado (ver ADR-001).
/// `Lc0Service.init()`/`StockfishService.init()` continuam, portanto,
/// só verificáveis de ponta a ponta via `integration_test/` em
/// dispositivo real.
///
/// O que É seguro extrair e testar sem FFI é a lógica de espera em si —
/// exatamente a parte responsável pelos dois bugs de concorrência
/// documentados em ADR-001 (corrida no dispose, handshake isready/readyok).
/// As duas funções abaixo operam só sobre `ValueListenable`/`Stream`
/// genéricos, o mesmo contrato que `Lc0.state`/`.stdout` e
/// `Stockfish.state`/`.stdout` já expõem, e por isso podem ser testadas
/// com um `ValueNotifier`/`StreamController` comuns.

/// Espera de forma cancelável até [predicate] ser verdadeiro para o valor
/// atual de [listenable]. Resolve imediatamente se já for verdadeiro ao
/// ser chamada. Não aplica timeout: quem chama decide com
/// `.future.timeout(...)`, preservando a mensagem de cada chamador; por
/// isso `cancel` também fica a cargo de quem chama, tipicamente em um
/// bloco `finally`, para nunca deixar um listener pendurado em
/// [listenable] depois de um timeout.
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

/// Extrai o lance de uma linha `bestmove <uci> [ponder ...]` da resposta
/// UCI de lc0/Stockfish. Retorna string vazia se a linha não tiver um
/// segundo token (não deveria acontecer em resposta bem formada, mas os
/// chamadores tratam esse caso como "nenhum lance válido").
String parseBestMove(String line) {
  final parts = line.trim().split(RegExp(r'\s+'));
  return parts.length > 1 ? parts[1] : '';
}

/// Espera de forma cancelável até uma linha de [stdout] satisfazer
/// [predicate]. Se o stream terminar antes disso (`onDone`), o `Future`
/// falha com o erro produzido por [onStreamDone] (mensagem específica de
/// cada chamador, ex.: "lc0 encerrou antes de responder readyok"). Mesmo
/// contrato de cancelamento explícito de [awaitListenableValue], para uso
/// em `finally` junto de `.future.timeout(...)`.
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
