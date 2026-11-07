import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/core/theming/board_theme.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'package:maia_chess/features/settings/presentation/appearance_screen.dart';
import 'package:maia_chess/main.dart';

Finder _appearanceScrollable() => find
    .descendant(
      of: find.byType(AppearanceScreen),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets(
    'saves appearance, updates preview, and preserves clock settings when reopened',
    (tester) async {
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
      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();

      final blue = find.byKey(const ValueKey('board-theme-blue'));
      await tester.scrollUntilVisible(
        blue,
        200,
        scrollable: _appearanceScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(blue);
      await tester.pumpAndSettle();
      expect(repository.settings.boardTheme, BoardTheme.blue);
      expect(repository.settings.defaultClockEnabled, isTrue);
      expect(repository.settings.defaultTimeMinutes, 15);
      await tester.scrollUntilVisible(
        find.byKey(const Key('chess-board-background')),
        -200,
        scrollable: _appearanceScrollable(),
      );
      await tester.pumpAndSettle();
      final background = tester.widget<Image>(
        find.byKey(const Key('chess-board-background')),
      );
      final image =
          (background.image as ResizeImage).imageProvider as AssetImage;
      expect(image.assetName, BoardTheme.blue.assetPath);

      final selector = find.byKey(const ValueKey('select-theme-dark'));
      await tester.scrollUntilVisible(
        selector,
        200,
        scrollable: _appearanceScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(repository.settings.themeMode, StoredThemeMode.dark);
      expect(Theme.of(tester.element(selector)).brightness, Brightness.dark);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('theme-mode-dark')),
        200,
        scrollable: _appearanceScrollable(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('theme-mode-dark')), findsOneWidget);
      expect(repository.settings.boardTheme, BoardTheme.blue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('board palettes expose a selected state and a TalkBack action', (
    tester,
  ) async {
    final repository = _SettingsRepository();
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AppearanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final blue = find.byKey(const ValueKey('board-theme-blue'));
    await tester.scrollUntilVisible(
      blue,
      200,
      scrollable: _appearanceScrollable(),
    );
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('Blue board'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(repository.settings.boardTheme, BoardTheme.blue);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Blue board'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('failed appearance save preserves the current setting', (
    tester,
  ) async {
    final repository = _SettingsRepository()..failSave = true;
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AppearanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final dark = find.byKey(const ValueKey('select-theme-dark'));
    await tester.scrollUntilVisible(
      dark,
      200,
      scrollable: _appearanceScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect(repository.settings.themeMode, StoredThemeMode.system);
    expect(find.text('Could not save appearance settings.'), findsOneWidget);
    repository.failSave = false;
    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect(repository.settings.themeMode, StoredThemeMode.dark);
  });

  testWidgets('appearance fits a short screen with enlarged text', (
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
      scrollable: _appearanceScrollable(),
    );
    await tester.pumpAndSettle();
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
  bool failSave = false;

  @override
  Stream<StoredAppSettings> watch() async* {
    yield settings;
    yield* updates.stream;
  }

  @override
  Future<StoredAppSettings> get() async => settings;

  @override
  Future<void> save(StoredAppSettings value) async {
    if (failSave) throw StateError('Temporary write failure');
    settings = value;
    updates.add(value);
  }
}
