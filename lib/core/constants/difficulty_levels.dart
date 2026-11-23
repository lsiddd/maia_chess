/// A skill input to the shared Maia-3 79M network.
class DifficultyLevel {
  const DifficultyLevel({required this.rating});

  final int rating;

  @override
  String toString() => 'Maia-3 $rating';

  static const all = [
    DifficultyLevel(rating: 600),
    DifficultyLevel(rating: 800),
    DifficultyLevel(rating: 1000),
    DifficultyLevel(rating: 1100),
    DifficultyLevel(rating: 1200),
    DifficultyLevel(rating: 1300),
    DifficultyLevel(rating: 1400),
    DifficultyLevel(rating: 1500),
    DifficultyLevel(rating: 1600),
    DifficultyLevel(rating: 1700),
    DifficultyLevel(rating: 1800),
    DifficultyLevel(rating: 1900),
    DifficultyLevel(rating: 2000),
    DifficultyLevel(rating: 2200),
    DifficultyLevel(rating: 2400),
    DifficultyLevel(rating: 2600),
  ];

  static DifficultyLevel byRating(int rating) =>
      all.firstWhere((level) => level.rating == rating);
}
