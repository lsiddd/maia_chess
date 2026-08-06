/// Resultado da dica dupla (seção 5 da especificação): o lance que um
/// jogador do nível atual provavelmente jogaria (Maia/lc0) lado a lado com
/// o lance objetivamente melhor (Stockfish), ambos em notação SAN.
class HintResult {
  const HintResult({
    required this.levelRating,
    required this.maiaSan,
    required this.stockfishSan,
  });

  /// Nível (1100-1900) usado para a sugestão "estilo humano".
  final int levelRating;

  /// Lance sugerido pelo Maia no nível atual, em SAN (ex: "Cf3").
  final String maiaSan;

  /// Lance objetivamente melhor segundo o Stockfish, em SAN.
  final String stockfishSan;
}
