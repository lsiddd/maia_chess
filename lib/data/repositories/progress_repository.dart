import '../../features/difficulty/domain/campaign_wins.dart';

class DifficultyProgressModel {
  const DifficultyProgressModel({
    required this.rating,
    required this.wins,
    required this.unlocked,
    required this.updatedAtUtc,
  });

  final int rating;
  final CampaignWins wins;
  final bool unlocked;
  final DateTime updatedAtUtc;

  bool get levelCompleted => wins.completed;
}

abstract interface class ProgressRepository {
  Stream<List<DifficultyProgressModel>> watchAll();

  Future<List<DifficultyProgressModel>> getAll();
}
