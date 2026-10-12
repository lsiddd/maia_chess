import 'package:dartchess/dartchess.dart';

/// Rules-validated hint bound to the analysed position.
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
