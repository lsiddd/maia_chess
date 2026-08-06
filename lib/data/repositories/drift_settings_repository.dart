import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'settings_repository.dart';

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<StoredAppSettings> watch() {
    return (_db.select(
      _db.appSettings,
    )..where((row) => row.id.equals(1))).watchSingle().map(_map);
  }

  @override
  Future<StoredAppSettings> get() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((row) => row.id.equals(1))).getSingle();
    return _map(row);
  }

  @override
  Future<void> save(StoredAppSettings settings) async {
    if (settings.defaultTimeMinutes <= 0) {
      throw ArgumentError.value(
        settings.defaultTimeMinutes,
        'defaultTimeMinutes',
        'deve ser positivo',
      );
    }
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            pieceSet: Value(settings.pieceSet.name),
            themeMode: Value(settings.themeMode.name),
            defaultClockEnabled: Value(settings.defaultClockEnabled),
            defaultTimeMinutes: Value(settings.defaultTimeMinutes),
            updatedAtUtc: DateTime.now().toUtc(),
          ),
        );
  }

  StoredAppSettings _map(AppSettingsRow row) {
    return StoredAppSettings(
      pieceSet: StoredPieceSet.values.byName(row.pieceSet),
      themeMode: StoredThemeMode.values.byName(row.themeMode),
      defaultClockEnabled: row.defaultClockEnabled,
      defaultTimeMinutes: row.defaultTimeMinutes,
    );
  }
}
