/// One of nine Maia levels, each backed by an official `.pb.gz` network from
/// `CSSLab/maia-chess`.
class DifficultyLevel {
  const DifficultyLevel({
    required this.rating,
    required this.weightsAsset,
    this.winsRequired = 2,
    this.windowSize = 3,
  }) : assert(winsRequired > 0),
       assert(windowSize >= winsRequired);

  /// Rating band of the human playing style modelled by the network
  /// (1100–1900).
  final int rating;

  /// Asset path of the corresponding `.pb.gz` network.
  final String weightsAsset;

  /// Wins required to complete this campaign level.
  final int winsRequired;

  /// Maximum size of the rolling campaign window.
  final int windowSize;

  @override
  String toString() => 'Maia $rating';

  /// All nine levels in ascending rating order.
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
