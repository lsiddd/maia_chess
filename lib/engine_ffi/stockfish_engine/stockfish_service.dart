import 'dart:async';
import 'dart:developer' as developer;

import 'package:stockfish/stockfish.dart';

/// Serviço de alto nível para o motor Stockfish, usado para a dica de lance
/// objetivamente melhor (independente do nível de dificuldade escolhido).
///
/// Mesma arquitetura do [Lc0Service]: FFI in-process via o pacote
/// `stockfish`, sem subprocess, com o laço UCI rodando em Isolate dedicado.
abstract interface class StockfishEngine {
  bool get isReady;

  Future<void> init();
  Future<String> getBestMove(String fen, {int movetimeMs = 1500});
  Future<void> dispose();
}

class StockfishService implements StockfishEngine {
  static const _startupTimeout = Duration(seconds: 20);
  static const _readyTimeout = Duration(seconds: 60);
  static const _stopGracePeriod = Duration(seconds: 2);

  Stockfish? _engine;
  bool _handshakeDone = false;
  bool _searchInProgress = false;

  /// `true` só depois do handshake `isready`/`readyok` (ver [init]) —
  /// diferente de `_engine.state == StockfishState.ready`, que só indica
  /// que o isolate nativo subiu, não que a NNUE embutida já foi carregada
  /// (mesma pegadinha documentada em [Lc0Service.isReady]).
  @override
  bool get isReady =>
      _engine != null &&
      _engine!.state.value == StockfishState.ready &&
      _handshakeDone;

  /// Inicializa o motor. O Stockfish embute a rede de avaliação (NNUE) no
  /// binário compilado, então não recebe um caminho de peso como o lc0.
  @override
  Future<void> init() async {
    if (_engine != null) {
      await dispose();
    }

    _handshakeDone = false;
    developer.log('Criando engine', name: 'StockfishService');
    final completer = Completer<void>();
    final engine = Stockfish();
    _engine = engine;

    void listener() {
      final state = engine.state.value;
      developer.log('Estado nativo: $state', name: 'StockfishService');
      if (state == StockfishState.ready) {
        engine.state.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      } else if (state == StockfishState.error) {
        engine.state.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(StateError('Stockfish falhou ao iniciar'));
        }
      }
    }

    engine.state.addListener(listener);
    if (engine.state.value == StockfishState.ready) {
      listener();
    }

    try {
      await completer.future.timeout(
        _startupTimeout,
        onTimeout: () =>
            throw TimeoutException('Stockfish não inicializou a tempo'),
      );

      // Ver o comentário equivalente em Lc0Service.init: `ready` só significa
      // que o isolate subiu, não que a NNUE terminou de carregar. Confirmamos
      // com o handshake padrão isready/readyok antes de liberar o motor para
      // buscas (ADR-001, observação de robustez, Fase 3).
      developer.log('Enviando isready', name: 'StockfishService');
      await _waitReadyOk(engine);
      if (!identical(_engine, engine)) {
        throw StateError('Stockfish foi descartado durante a inicialização');
      }
      _handshakeDone = true;
      developer.log('Handshake readyok concluído', name: 'StockfishService');
    } catch (error, stackTrace) {
      engine.state.removeListener(listener);
      developer.log(
        'Falha na inicialização',
        name: 'StockfishService',
        error: error,
        stackTrace: stackTrace,
      );
      await _disposeAfterFailure(engine);
      rethrow;
    }
  }

  Future<void> _waitReadyOk(Stockfish engine) async {
    final completer = Completer<void>();
    final sub = engine.stdout.listen(
      (line) {
        if (line.trim() == 'readyok' && !completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Stockfish encerrou antes de responder readyok'),
          );
        }
      },
    );
    try {
      engine.stdin = 'isready';
      await completer.future.timeout(
        _readyTimeout,
        onTimeout: () => throw TimeoutException(
          'Stockfish não respondeu isready/readyok em '
          '${_readyTimeout.inSeconds}s',
        ),
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Envia a posição [fen] e retorna o lance sugerido em notação UCI,
  /// buscando por [movetimeMs] milissegundos (padrão configurável entre
  /// ~1000-3000ms para a dica, conforme seção 7 da especificação).
  @override
  Future<String> getBestMove(String fen, {int movetimeMs = 1500}) async {
    if (!isReady) {
      throw StateError('Stockfish não está pronto. Chame init() primeiro.');
    }
    if (movetimeMs <= 0) {
      throw ArgumentError.value(movetimeMs, 'movetimeMs', 'deve ser positivo');
    }
    if (_searchInProgress) {
      throw StateError('Stockfish já está calculando outro lance');
    }

    final engine = _engine!;
    final completer = Completer<String>();
    final sub = engine.stdout.listen(
      (line) {
        if (line.startsWith('bestmove') && !completer.isCompleted) {
          final parts = line.trim().split(RegExp(r'\s+'));
          completer.complete(parts.length > 1 ? parts[1] : '');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Stockfish encerrou antes de devolver bestmove'),
          );
        }
      },
    );

    _searchInProgress = true;
    try {
      developer.log(
        'Iniciando busca movetime=${movetimeMs}ms',
        name: 'StockfishService',
      );
      engine.stdin = 'position fen $fen';
      engine.stdin = 'go movetime $movetimeMs';

      try {
        final move = await completer.future.timeout(
          Duration(milliseconds: movetimeMs + 8000),
        );
        if (move.isEmpty || move == '(none)') {
          throw StateError('Stockfish não devolveu um lance válido');
        }
        developer.log('Bestmove recebido: $move', name: 'StockfishService');
        return move;
      } on TimeoutException {
        // Interrompe uma busca atrasada para ela não deixar um `bestmove`
        // órfão no stream e contaminar a próxima solicitação.
        developer.log(
          'Busca excedeu o limite; enviando stop',
          name: 'StockfishService',
        );
        try {
          engine.stdin = 'stop';
          final move = await completer.future.timeout(_stopGracePeriod);
          if (move.isNotEmpty && move != '(none)') return move;
        } on Object {
          // O descarte abaixo é o caminho de recuperação.
        }
        await _disposeAfterFailure(engine);
        throw TimeoutException(
          'Stockfish não respondeu à busca nem ao comando stop',
        );
      }
    } finally {
      _searchInProgress = false;
      await sub.cancel();
    }
  }

  /// Encerra o motor e só retorna depois que o singleton nativo do pacote
  /// (`Stockfish`) terminou de verdade — ver o comentário equivalente em
  /// [Lc0Service.dispose] (mesmo pacote-padrão, mesma limitação: chamar
  /// [init] de novo cedo demais lança `Bad state: Multiple instances are
  /// not supported, yet.`).
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

    // `Stockfish.dispose()` escreve "quit" e por isso lança enquanto o
    // wrapper ainda está em `starting`. Aguarda a transição para que um
    // timeout de inicialização não transforme a própria limpeza em outro
    // erro e deixe o singleton preso.
    if (state == StockfishState.starting) {
      final startup = Completer<void>();
      void startupListener() {
        if (engine.state.value != StockfishState.starting &&
            !startup.isCompleted) {
          startup.complete();
        }
      }

      engine.state.addListener(startupListener);
      try {
        await startup.future.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        return;
      } finally {
        engine.state.removeListener(startupListener);
      }
      state = engine.state.value;
    }
    if (state != StockfishState.ready) return;

    final completer = Completer<void>();
    void listener() {
      final current = engine.state.value;
      if (current == StockfishState.disposed ||
          current == StockfishState.error) {
        engine.state.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    engine.state.addListener(listener);
    try {
      engine.dispose();
      await completer.future.timeout(const Duration(seconds: 5));
    } on Object catch (error, stackTrace) {
      developer.log(
        'Não foi possível encerrar o engine após a falha',
        name: 'StockfishService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      engine.state.removeListener(listener);
    }
  }
}
