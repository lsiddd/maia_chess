import '../../core/theming/board_theme.dart';

enum StoredThemeMode { system, light, dark }

enum StoredPieceSet { classic, cburnett }

class StoredAppSettings {
  const StoredAppSettings({
    this.pieceSet = StoredPieceSet.cburnett,
    this.boardTheme = BoardTheme.brown,
    this.themeMode = StoredThemeMode.system,
    this.defaultClockEnabled = false,
    this.defaultTimeMinutes = 10,
  });

  final StoredPieceSet pieceSet;
  final BoardTheme boardTheme;
  final StoredThemeMode themeMode;
  final bool defaultClockEnabled;
  final int defaultTimeMinutes;

  StoredAppSettings copyWith({
    BoardTheme? boardTheme,
    StoredThemeMode? themeMode,
  }) => StoredAppSettings(
    pieceSet: pieceSet,
    boardTheme: boardTheme ?? this.boardTheme,
    themeMode: themeMode ?? this.themeMode,
    defaultClockEnabled: defaultClockEnabled,
    defaultTimeMinutes: defaultTimeMinutes,
  );
}

abstract interface class SettingsRepository {
  Stream<StoredAppSettings> watch();

  Future<StoredAppSettings> get();

  Future<void> save(StoredAppSettings settings);
}
