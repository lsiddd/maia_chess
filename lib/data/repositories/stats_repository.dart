import '../../features/stats/domain/player_stats.dart';

abstract interface class StatsRepository {
  Stream<PlayerStatsSnapshot> watch();

  Future<PlayerStatsSnapshot> get();
}
