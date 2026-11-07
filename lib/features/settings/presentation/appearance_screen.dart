import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_theme.dart';
import '../../../core/theming/board_theme.dart';
import '../../../core/widgets/error_state_card.dart';
import '../../../core/widgets/max_width_body.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../game/presentation/chess_board_widget.dart';

class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  bool _saving = false;

  Future<void> _save({
    BoardTheme? boardTheme,
    StoredThemeMode? themeMode,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(settingsRepositoryProvider);
      final current = await repository.get();
      await repository.save(
        current.copyWith(boardTheme: boardTheme, themeMode: themeMode),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save appearance settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        top: false,
        child: MaxWidthBody(
          child: settings.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading appearance',
              ),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: ErrorStateCard(
                message: 'Could not load appearance settings.',
                onRetry: () => ref.invalidate(appSettingsProvider),
              ),
            ),
            data: (settings) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'Your board. Your style.',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Choose a comfortable setting for every game.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 224),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Semantics(
                                image: true,
                                label:
                                    '${settings.boardTheme.label} board preview with Cburnett pieces',
                                excludeSemantics: true,
                                child: StaticChessBoardWidget(
                                  position: Chess.initial,
                                  boardTheme: settings.boardTheme,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Text(
                          '${settings.boardTheme.label} · Cburnett pieces',
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeading(
                  title: 'App theme',
                  subtitle: 'Follow your device or choose a fixed theme.',
                ),
                const SizedBox(height: AppSpacing.m),
                Card(
                  key: ValueKey('theme-mode-${settings.themeMode.name}'),
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final mode in StoredThemeMode.values)
                        _ThemeModeOption(
                          mode: mode,
                          selected: settings.themeMode == mode,
                          onTap: _saving
                              ? null
                              : () => unawaited(_save(themeMode: mode)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionHeading(
                  title: 'Board',
                  subtitle: 'Preview a palette before your next move.',
                ),
                const SizedBox(height: AppSpacing.m),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 480 ? 3 : 2;
                    return Wrap(
                      spacing: AppSpacing.m,
                      runSpacing: AppSpacing.m,
                      children: [
                        for (final board in BoardTheme.values)
                          SizedBox(
                            width:
                                (constraints.maxWidth -
                                    AppSpacing.m * (columns - 1)) /
                                columns,
                            child: _BoardThemeOption(
                              theme: board,
                              selected: settings.boardTheme == board,
                              onTap: _saving
                                  ? null
                                  : () => _save(boardTheme: board),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.l),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _saving
                        ? 'Saving appearance…'
                        : 'Changes are saved automatically.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Credits and licences'),
                  subtitle: const Text('Cburnett and Lichess'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Maia Chess',
                    applicationLegalese:
                        'Pieces: Colin M. L. Burnett (GPL-2.0-or-later).\n'
                        'Boards: Lichess authors and pirouetti '
                        '(AGPL-3.0-or-later).',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final StoredThemeMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (mode) {
      StoredThemeMode.system => (
        'Follow system',
        Icons.brightness_auto_outlined,
      ),
      StoredThemeMode.light => ('Light', Icons.light_mode_outlined),
      StoredThemeMode.dark => ('Dark', Icons.dark_mode_outlined),
    };
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        key: ValueKey('select-theme-${mode.name}'),
        selected: selected,
        selectedTileColor: colors.primaryContainer,
        selectedColor: colors.onPrimaryContainer,
        leading: Icon(icon),
        title: Text(label),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _BoardThemeOption extends StatelessWidget {
  const _BoardThemeOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final BoardTheme theme;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      inMutuallyExclusiveGroup: true,
      label: '${theme.label} board',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('board-theme-${theme.name}'),
          onTap: onTap,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: AspectRatio(
                    aspectRatio: 2,
                    child: Image.asset(
                      theme.assetPath,
                      fit: BoxFit.cover,
                      cacheWidth: 256,
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.label,
                        style: TextStyle(
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
