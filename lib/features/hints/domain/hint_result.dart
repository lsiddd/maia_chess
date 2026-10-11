import 'package:dartchess/dartchess.dart';

/// Resultado validado pelo motor de regras, vinculado à posição analisada.
class HintResult {
  const HintResult({
    required this.fen,
    required this.move,
    required this.stockfishSan,
  });

  final String fen;
  final NormalMove move;
  final String stockfishSan;
}
