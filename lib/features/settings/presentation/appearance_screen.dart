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
          const SnackBar(content: Text('Não foi possível salvar a aparência.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: MaxWidthBody(
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: ErrorStateCard(
              message: 'Não foi possível carregar a aparência.',
              onRetry: () => ref.invalidate(appSettingsProvider),
            ),
          ),
          data: (settings) => ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              Center(
                child: SizedBox.square(
                  dimension: 240,
                  child: StaticChessBoardWidget(
                    position: Chess.initial,
                    boardTheme: settings.boardTheme,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              const Text('Peças Cburnett', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Tema do app',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.s),
              DropdownButtonFormField<StoredThemeMode>(
                isExpanded: true,
                key: ValueKey('theme-mode-${settings.themeMode.name}'),
                initialValue: settings.themeMode,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Aparência do app',
                ),
                items: const [
                  DropdownMenuItem(
                    value: StoredThemeMode.system,
                    child: Text(
                      'Seguir o sistema',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: StoredThemeMode.light,
                    child: Text('Claro', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: StoredThemeMode.dark,
                    child: Text('Escuro', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (mode) {
                        if (mode != null) unawaited(_save(themeMode: mode));
                      },
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Tabuleiro', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              const Text('Temas originais do Lichess. Brown é o padrão.'),
              const SizedBox(height: AppSpacing.m),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  children: [
                    for (final theme in BoardTheme.values)
                      SizedBox(
                        width: (constraints.maxWidth - AppSpacing.m) / 2,
                        child: _BoardThemeOption(
                          theme: theme,
                          selected: settings.boardTheme == theme,
                          onTap: _saving
                              ? null
                              : () => _save(boardTheme: theme),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('Créditos e licenças'),
                subtitle: const Text('Cburnett e Lichess'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Xadrez Maia',
                  applicationLegalese:
                      'Peças: Colin M. L. Burnett (GPL-2.0-or-later).\n'
                      'Tabuleiros: autores do Lichess e pirouetti '
                      '(AGPL-3.0-or-later).',
                ),
              ),
            ],
          ),
        ),
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
      label: 'Tabuleiro ${theme.label}',
      child: Card(
        margin: EdgeInsets.zero,
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
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 72,
                  child: Image.asset(
                    theme.assetPath,
                    cacheWidth: 128,
                    filterQuality: FilterQuality.none,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Flexible(child: Text(theme.label)),
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
