class DifficultyProgressModel {
  const DifficultyProgressModel({
    required this.rating,
    required this.validWins,
    required this.gamesInWindow,
    required this.unlocked,
    required this.winsRequired,
    required this.windowSize,
    required this.updatedAtUtc,
  });

  final int rating;
  final int validWins;
  final int gamesInWindow;
  final bool unlocked;
  final int winsRequired;
  final int windowSize;
  final DateTime updatedAtUtc;

  bool get levelCompleted => validWins >= winsRequired;
}

abstract interface class ProgressRepository {
  Stream<List<DifficultyProgressModel>> watchAll();

  Future<List<DifficultyProgressModel>> getAll();
}
