import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/core/theming/board_theme.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'package:maia_chess/features/settings/presentation/appearance_screen.dart';
import 'package:maia_chess/main.dart';

void main() {
  testWidgets('salva aparência, atualiza prévia e mantém relógio ao reabrir', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final repository = _SettingsRepository();
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeGameProvider.overrideWith((ref) => Stream.value(null)),
          settingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaiaChessApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();

    final blue = find.byKey(const ValueKey('board-theme-blue'));
    await tester.ensureVisible(blue);
    await tester.tap(blue);
    await tester.pumpAndSettle();
    expect(repository.settings.boardTheme, BoardTheme.blue);
    expect(repository.settings.defaultClockEnabled, isTrue);
    expect(repository.settings.defaultTimeMinutes, 15);
    final background = tester.widget<Image>(
      find.byKey(const Key('chess-board-background')),
    );
    final image = (background.image as ResizeImage).imageProvider as AssetImage;
    expect(image.assetName, BoardTheme.blue.assetPath);

    final selector = find.byType(DropdownButtonFormField<StoredThemeMode>);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro').last);
    await tester.pumpAndSettle();
    expect(repository.settings.themeMode, StoredThemeMode.dark);
    expect(Theme.of(tester.element(selector)).brightness, Brightness.dark);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme-mode-dark')), findsOneWidget);
    expect(repository.settings.boardTheme, BoardTheme.blue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aparência cabe em tela baixa com fonte ampliada', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);
    final repository = _SettingsRepository();
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeGameProvider.overrideWith((ref) => Stream.value(null)),
          settingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('board-theme-purple')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _SettingsRepository implements SettingsRepository {
  StoredAppSettings settings = const StoredAppSettings(
    defaultClockEnabled: true,
    defaultTimeMinutes: 15,
  );
  final updates = StreamController<StoredAppSettings>.broadcast();

  @override
  Stream<StoredAppSettings> watch() async* {
    yield settings;
    yield* updates.stream;
  }

  @override
  Future<StoredAppSettings> get() async => settings;

  @override
  Future<void> save(StoredAppSettings value) async {
    settings = value;
    updates.add(value);
  }
}
