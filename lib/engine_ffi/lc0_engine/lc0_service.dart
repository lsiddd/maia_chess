import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:leela_chess_zero/lc0.dart';
import 'package:path_provider/path_provider.dart';

/// Serviço de alto nível para o motor lc0, usado para imitar o estilo de
/// jogo humano através dos pesos Maia (ver ADR-001).
///
/// Encapsula o pacote `leela_chess_zero`, que executa o lc0 in-process via
/// Dart FFI (sem subprocess, compatível com as restrições W^X do Android
/// desde a API 29), falando o protocolo UCI internamente em um Isolate
/// dedicado para não bloquear a UI.
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

  Lc0? _engine;
  String? _loadedWeightsPath;
  bool _handshakeDone = false;
  bool _searchInProgress = false;

  /// Caminho do peso atualmente carregado, ou `null` se nenhum motor ativo.
  @override
  String? get loadedWeightsPath => _loadedWeightsPath;

  /// `true` só depois do handshake `isready`/`readyok` (ver [init]) —
  /// diferente de `_engine.state == Lc0State.ready`, que só indica que o
  /// isolate nativo subiu, não que o motor terminou de carregar os pesos.
  @override
  bool get isReady =>
      _engine != null &&
      _engine!.state.value == Lc0State.ready &&
      _handshakeDone;

  /// Inicializa o motor com o peso `.pb.gz` em [weightsFilePath] (caminho
  /// absoluto no filesystem — o lc0 não consegue ler de dentro do asset
  /// bundle compactado do APK). Use [extractWeightsAsset] antes, se o peso
  /// vier de um asset.
  ///
  /// Só uma instância do lc0 pode existir por vez (limitação do pacote
  /// subjacente); troca de nível de dificuldade passa por [dispose] seguido
  /// de um novo [init].
  @override
  Future<void> init(String weightsFilePath) async {
    if (_engine != null) {
      await dispose();
    }

    _handshakeDone = false;
    final completer = Completer<void>();
    final engine = Lc0(weightsPath: weightsFilePath);
    _engine = engine;

    void listener() {
      final state = engine.state.value;
      if (state == Lc0State.ready) {
        engine.state.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      } else if (state == Lc0State.error) {
        engine.state.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(StateError('lc0 falhou ao iniciar'));
        }
      }
    }

    engine.state.addListener(listener);
    // Cobre o caso (improvável, mas possível) de já estar pronto antes do
    // listener ser registrado.
    if (engine.state.value == Lc0State.ready) {
      listener();
    }

    try {
      await completer.future.timeout(
        _startupTimeout,
        onTimeout: () => throw TimeoutException(
          'lc0 não inicializou em ${_startupTimeout.inSeconds}s',
        ),
      );

      // `Lc0State.ready` só significa que o isolate nativo subiu — o
      // carregamento de fato dos pesos (parsing do .pb.gz) acontece depois,
      // de forma assíncrona, e pode levar dezenas de segundos (observado na
      // prática: até ~25s entre o motor iniciar e terminar de carregar).
      // Mandar "go" antes disso faz o comando ficar preso atrás do
      // carregamento na fila de stdin, e nosso timeout de getBestMove
      // estourava achando que o motor tinha travado. Corrigido aguardando o
      // handshake padrão UCI isready/readyok, que só responde depois que o
      // motor processa tudo que veio antes — ver ADR-001, observação de
      // robustez (Fase 3).
      await _waitReadyOk(engine);
      if (!identical(_engine, engine)) {
        throw StateError('lc0 foi descartado durante a inicialização');
      }
      _loadedWeightsPath = weightsFilePath;
      _handshakeDone = true;
    } catch (_) {
      engine.state.removeListener(listener);
      await _disposeAfterFailure(engine);
      rethrow;
    }
  }

  Future<void> _waitReadyOk(Lc0 engine) async {
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
            StateError('lc0 encerrou antes de responder readyok'),
          );
        }
      },
    );
    try {
      engine.stdin = 'isready';
      await completer.future.timeout(
        _readyTimeout,
        onTimeout: () => throw TimeoutException(
          'lc0 não respondeu isready/readyok em '
          '${_readyTimeout.inSeconds}s (carregamento dos pesos)',
        ),
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Envia a posição [fen] ao motor e retorna o lance sugerido em notação
  /// UCI (ex: `e2e4`), usando busca com [nodes] posições (padrão 1 — uma
  /// única passada de avaliação de política, sem árvore de busca: é assim
  /// que os pesos Maia foram desenhados/validados para imitar um jogador
  /// humano daquele nível).
  @override
  Future<String> getBestMove(String fen, {int nodes = 1}) async {
    if (!isReady) {
      throw StateError('lc0 não está pronto. Chame init() primeiro.');
    }
    if (nodes <= 0) {
      throw ArgumentError.value(nodes, 'nodes', 'deve ser positivo');
    }
    if (_searchInProgress) {
      throw StateError('lc0 já está calculando outro lance');
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
            StateError('lc0 encerrou antes de devolver bestmove'),
          );
        }
      },
    );

    _searchInProgress = true;
    try {
      engine.stdin = 'position fen $fen';
      engine.stdin = 'go nodes $nodes';
      try {
        final move = await completer.future.timeout(
          const Duration(seconds: 10),
        );
        if (move.isEmpty || move == '(none)') {
          throw StateError('lc0 não devolveu um lance válido');
        }
        return move;
      } on TimeoutException {
        // Assim como no Stockfish, uma busca atrasada não pode deixar um
        // `bestmove` órfão que seria confundido com a solicitação seguinte.
        try {
          engine.stdin = 'stop';
          final move = await completer.future.timeout(_stopGracePeriod);
          if (move.isNotEmpty && move != '(none)') return move;
        } on Object {
          // O descarte abaixo é o caminho de recuperação.
        }
        await _disposeAfterFailure(engine);
        throw TimeoutException('lc0 não respondeu à busca nem ao comando stop');
      }
    } finally {
      _searchInProgress = false;
      await sub.cancel();
    }
  }

  /// Encerra o motor e só retorna depois que o singleton nativo do pacote
  /// (`Lc0`) terminou de verdade.
  ///
  /// Importante: `Lc0.dispose()` só manda "quit" pelo stdin — a limpeza de
  /// fato (`_cleanUp`, que zera o singleton estático do pacote) acontece
  /// depois, quando o isolate do motor processa o "quit" e sai. Se
  /// [init] for chamado de novo antes disso terminar, o pacote lança
  /// `Bad state: Multiple instances are not supported, yet.` (visto na
  /// prática ao trocar de nível/reiniciar contra a IA — ver ADR-001,
  /// observação de robustez). Por isso esperamos aqui o estado virar
  /// [Lc0State.disposed] (ou [Lc0State.error]) antes de liberar o serviço.
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

    // O wrapper nativo só aceita `quit` depois de entrar em ready. Se a
    // falha ocorreu durante o curtíssimo bootstrap do isolate, aguarda essa
    // transição antes de tentar a saída limpa.
    if (current == Lc0State.starting) {
      final startup = Completer<void>();
      void startupListener() {
        if (engine.state.value != Lc0State.starting && !startup.isCompleted) {
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
      current = engine.state.value;
    }
    if (current != Lc0State.ready) return;

    final disposed = Completer<void>();
    void listener() {
      final state = engine.state.value;
      if ((state == Lc0State.disposed || state == Lc0State.error) &&
          !disposed.isCompleted) {
        disposed.complete();
      }
    }

    engine.state.addListener(listener);
    try {
      engine.dispose();
      await disposed.future.timeout(const Duration(seconds: 5));
    } on Object {
      // Não há API de kill no pacote; o singleton será liberado quando o
      // loop UCI consumir o `quit`.
    } finally {
      engine.state.removeListener(listener);
    }
  }

  /// Copia um peso `.pb.gz` de um asset do bundle Flutter para um arquivo
  /// gravável no armazenamento do app, retornando o caminho absoluto. Só
  /// copia de novo se o arquivo ainda não existir ou tiver tamanho
  /// diferente do asset de origem.
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
