enum StoredThemeMode { system, light, dark }

enum StoredPieceSet { classic }

class StoredAppSettings {
  const StoredAppSettings({
    this.pieceSet = StoredPieceSet.classic,
    this.themeMode = StoredThemeMode.system,
    this.defaultClockEnabled = false,
    this.defaultTimeMinutes = 10,
  });

  final StoredPieceSet pieceSet;
  final StoredThemeMode themeMode;
  final bool defaultClockEnabled;
  final int defaultTimeMinutes;
}

abstract interface class SettingsRepository {
  Stream<StoredAppSettings> watch();

  Future<StoredAppSettings> get();

  Future<void> save(StoredAppSettings settings);
}
