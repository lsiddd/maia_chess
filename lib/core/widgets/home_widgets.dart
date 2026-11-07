import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/repositories/game_repository.dart';
import '../theming/app_theme.dart';

class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.savedGame,
    required this.loading,
    required this.opening,
    required this.onPlay,
    super.key,
  });

  final GameSummary? savedGame;
  final bool loading;
  final bool opening;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final saved = savedGame;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A HUMAN SIDE TO CHESS',
                      style: text.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      saved == null ? 'Your next move.' : 'Back to the board.',
                      style: text.headlineLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 380 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 20) ...[
                const SizedBox(width: AppSpacing.s),
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    'assets/chess_pieces/wN.svg',
                    width: 56,
                    height: 72,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            saved == null
                ? 'Find your rhythm against an AI that plays like a person. Always offline.'
                : '${saved.levelRating == null ? 'Local game' : 'Maia · ${saved.levelRating}'} · ${saved.moveCount} moves played. Pick up where you left off.',
            style: text.bodyMedium?.copyWith(color: colors.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onPlay,
            icon: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    opening
                        ? Icons.hourglass_top_rounded
                        : Icons.play_arrow_rounded,
                  ),
            label: Text(
              loading
                  ? 'Checking saved game…'
                  : saved == null
                  ? 'Free play against Maia-3'
                  : 'Continue saved game',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSectionHeading extends StatelessWidget {
  const HomeSectionHeading({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class HomeActionTile extends StatelessWidget {
  const HomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.outlined = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      enabled: onTap != null,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
    return outlined ? Card(child: tile) : tile;
  }
}
