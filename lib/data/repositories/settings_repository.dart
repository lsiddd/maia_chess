import '../../core/theming/board_theme.dart';

enum StoredThemeMode { system, light, dark }

enum StoredPieceSet { classic, cburnett }

class StoredAppSettings {
  const StoredAppSettings({
    this.showAttackedPieces = false,
    this.ownAttackedPiecesOnly = false,
    this.pieceSet = StoredPieceSet.cburnett,
    this.boardTheme = BoardTheme.brown,
    this.themeMode = StoredThemeMode.system,
    this.defaultClockEnabled = false,
    this.defaultTimeMinutes = 10,
  });

  final bool showAttackedPieces;
  final bool ownAttackedPiecesOnly;
  final StoredPieceSet pieceSet;
  final BoardTheme boardTheme;
  final StoredThemeMode themeMode;
  final bool defaultClockEnabled;
  final int defaultTimeMinutes;

  StoredAppSettings copyWith({
    bool? showAttackedPieces,
    bool? ownAttackedPiecesOnly,
    BoardTheme? boardTheme,
    StoredThemeMode? themeMode,
  }) => StoredAppSettings(
    showAttackedPieces: showAttackedPieces ?? this.showAttackedPieces,
    ownAttackedPiecesOnly: ownAttackedPiecesOnly ?? this.ownAttackedPiecesOnly,
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
