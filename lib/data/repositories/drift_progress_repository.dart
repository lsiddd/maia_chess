import 'package:drift/drift.dart';

import '../../features/difficulty/domain/campaign_wins.dart';
import '../local/app_database.dart';
import 'progress_repository.dart';

class DriftProgressRepository implements ProgressRepository {
  DriftProgressRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<DifficultyProgressModel>> watchAll() {
    final query = _db.select(_db.difficultyProgress)
      ..orderBy([(row) => OrderingTerm.asc(row.rating)]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Future<List<DifficultyProgressModel>> getAll() async {
    final query = _db.select(_db.difficultyProgress)
      ..orderBy([(row) => OrderingTerm.asc(row.rating)]);
    return (await query.get()).map(_map).toList(growable: false);
  }

  DifficultyProgressModel _map(DifficultyProgressRow row) {
    return DifficultyProgressModel(
      rating: row.rating,
      wins: CampaignWins(white: row.whiteWins, black: row.blackWins),
      unlocked: row.unlocked,
      updatedAtUtc: row.updatedAtUtc.toUtc(),
    );
  }
}
