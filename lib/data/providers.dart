import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../features/stats/domain/player_stats.dart';
import 'local/app_database.dart';
import 'repositories/drift_game_repository.dart';
import 'repositories/drift_progress_repository.dart';
import 'repositories/drift_settings_repository.dart';
import 'repositories/drift_stats_repository.dart';
import 'repositories/game_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/stats_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final gameRepositoryProvider = Provider<GameRepository>(
  (ref) => DriftGameRepository(ref.watch(appDatabaseProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => DriftProgressRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(appDatabaseProvider)),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => DriftStatsRepository(ref.watch(appDatabaseProvider)),
);

final gameIdFactoryProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

final activeGameProvider = StreamProvider<StoredGame?>(
  (ref) => ref.watch(gameRepositoryProvider).watchActiveGame(),
);

final gameLibraryProvider = StreamProvider<List<StoredGame>>(
  (ref) => ref.watch(gameRepositoryProvider).watchLibrary(),
);

final difficultyProgressProvider =
    StreamProvider<List<DifficultyProgressModel>>(
      (ref) => ref.watch(progressRepositoryProvider).watchAll(),
    );

final appSettingsProvider = StreamProvider<StoredAppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

final playerStatsProvider = StreamProvider<PlayerStatsSnapshot>(
  (ref) => ref.watch(statsRepositoryProvider).watch(),
);
