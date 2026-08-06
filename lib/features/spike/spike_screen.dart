import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine_ffi/lc0_engine/lc0_service.dart';
import '../../engine_ffi/stockfish_engine/stockfish_service.dart';

/// Tela de diagnóstico da Fase 0 (spike técnico).
///
/// Critério de aceite (seção 6 da especificação): um botão carrega um peso
/// Maia, envia um FEN fixo e recebe um lance via FFI; o mesmo para o
/// Stockfish. Esta tela existe só para validar a viabilidade da arquitetura
/// de FFI in-process; a UI de jogo real vive em `features/game`.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

/// FEN fixo usado no spike: posição inicial padrão do xadrez.
const _testFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Usa o mesmo peso oficial empacotado pelo app real. Assim o diagnóstico
/// também detecta regressões no manifesto de assets da aplicação.
const _maiaWeightsAsset = 'assets/maia_weights/maia-1900.pb.gz';

class _SpikeScreenState extends State<SpikeScreen> {
  final _lc0 = Lc0Service();
  final _stockfish = StockfishService();

  String _lc0Status = 'Ocioso';
  String? _lc0Move;
  bool _lc0Busy = false;

  String _stockfishStatus = 'Ocioso';
  String? _stockfishMove;
  bool _stockfishBusy = false;

  void _update(VoidCallback update) {
    if (mounted) setState(update);
  }

  Future<void> _runLc0() async {
    _update(() {
      _lc0Busy = true;
      _lc0Move = null;
      _lc0Status = 'Extraindo peso Maia-1900 dos assets...';
    });
    try {
      final weightsPath = await Lc0Service.extractWeightsAsset(
        _maiaWeightsAsset,
      );
      _update(() => _lc0Status = 'Inicializando motor lc0...');
      await _lc0.init(weightsPath);
      _update(
        () => _lc0Status = 'Enviando FEN e aguardando lance (nodes=1)...',
      );
      final move = await _lc0.getBestMove(_testFen, nodes: 1);
      _update(() {
        _lc0Status = 'OK';
        _lc0Move = move;
      });
    } catch (e) {
      _update(() => _lc0Status = 'Erro: $e');
    } finally {
      _update(() => _lc0Busy = false);
    }
  }

  Future<void> _runStockfish() async {
    _update(() {
      _stockfishBusy = true;
      _stockfishMove = null;
      _stockfishStatus = 'Inicializando motor Stockfish...';
    });
    try {
      await _stockfish.init();
      _update(() => _stockfishStatus = 'Enviando FEN e buscando lance...');
      final move = await _stockfish.getBestMove(_testFen, movetimeMs: 1000);
      _update(() {
        _stockfishStatus = 'OK';
        _stockfishMove = move;
      });
    } catch (e) {
      _update(() => _stockfishStatus = 'Erro: $e');
    } finally {
      _update(() => _stockfishBusy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_lc0.dispose());
    unawaited(_stockfish.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico Fase 0 — lc0 / Stockfish')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EngineCard(
            title: 'Maia (lc0 via FFI)',
            status: _lc0Status,
            move: _lc0Move,
            busy: _lc0Busy,
            onPressed: _runLc0,
          ),
          const SizedBox(height: 16),
          _EngineCard(
            title: 'Stockfish (via FFI)',
            status: _stockfishStatus,
            move: _stockfishMove,
            busy: _stockfishBusy,
            onPressed: _runStockfish,
          ),
        ],
      ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({
    required this.title,
    required this.status,
    required this.move,
    required this.busy,
    required this.onPressed,
  });

  final String title;
  final String status;
  final String? move;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Status: $status'),
            if (move != null) ...[
              const SizedBox(height: 8),
              Text(
                'Lance recebido: $move',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Testar'),
            ),
          ],
        ),
      ),
    );
  }
}
