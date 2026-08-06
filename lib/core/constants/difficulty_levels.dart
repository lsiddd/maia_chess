/// Um dos 9 níveis de dificuldade do Maia (seção 3 da especificação),
/// cada um correspondendo a um peso `.pb.gz` oficial do repositório
/// `CSSLab/maia-chess` (ver ADR-007).
class DifficultyLevel {
  const DifficultyLevel({
    required this.rating,
    required this.weightsAsset,
    this.winsRequired = 2,
    this.windowSize = 3,
  }) : assert(winsRequired > 0),
       assert(windowSize >= winsRequired);

  /// Rating aproximado do estilo de jogo imitado (1100-1900).
  final int rating;

  /// Caminho do asset do peso `.pb.gz` correspondente.
  final String weightsAsset;

  /// Vitórias necessárias para concluir este nível no modo campanha.
  final int winsRequired;

  /// Tamanho máximo da janela móvel considerada na campanha.
  final int windowSize;

  @override
  String toString() => 'Maia $rating';

  /// Todos os 9 níveis, em ordem crescente de rating.
  static const all = [
    DifficultyLevel(
      rating: 1100,
      weightsAsset: 'assets/maia_weights/maia-1100.pb.gz',
    ),
    DifficultyLevel(
      rating: 1200,
      weightsAsset: 'assets/maia_weights/maia-1200.pb.gz',
    ),
    DifficultyLevel(
      rating: 1300,
      weightsAsset: 'assets/maia_weights/maia-1300.pb.gz',
    ),
    DifficultyLevel(
      rating: 1400,
      weightsAsset: 'assets/maia_weights/maia-1400.pb.gz',
    ),
    DifficultyLevel(
      rating: 1500,
      weightsAsset: 'assets/maia_weights/maia-1500.pb.gz',
    ),
    DifficultyLevel(
      rating: 1600,
      weightsAsset: 'assets/maia_weights/maia-1600.pb.gz',
    ),
    DifficultyLevel(
      rating: 1700,
      weightsAsset: 'assets/maia_weights/maia-1700.pb.gz',
    ),
    DifficultyLevel(
      rating: 1800,
      weightsAsset: 'assets/maia_weights/maia-1800.pb.gz',
    ),
    DifficultyLevel(
      rating: 1900,
      weightsAsset: 'assets/maia_weights/maia-1900.pb.gz',
    ),
  ];

  static DifficultyLevel byRating(int rating) =>
      all.firstWhere((l) => l.rating == rating);
}
