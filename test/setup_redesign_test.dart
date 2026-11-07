import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/core/theming/app_theme.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/progress_repository.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/difficulty/presentation/new_game_vs_ai_screen.dart';
import 'package:maia_chess/features/game/application/time_control.dart';
import 'package:maia_chess/features/game/presentation/time_control_picker.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('free play keeps start reachable with large text ($dark)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24),
              ),
              child: child!,
            ),
            home: const NewGameVsAiScreen(),
          ),
        ),
      );
      final start = find.widgetWithText(FilledButton, 'Start game');
      expect(start.hitTestable(), findsOneWidget);
      final initialPosition = tester.getBottomRight(start);
      expect(initialPosition.dy, lessThanOrEqualTo(616));
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(start.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(start), initialPosition);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'rating cells keep their position when selection changes at ${scale}x',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 1000);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const NewGameVsAiScreen(),
            ),
          ),
        );
        for (final rating in [800, 1300, 2600]) {
          final selected = find.byKey(ValueKey('level-$rating'));
          await tester.scrollUntilVisible(
            selected,
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final choices = find.descendant(
            of: find.byKey(const Key('rating-options')),
            matching: find.byType(ChoiceChip),
          );
          List<Rect> positions() {
            final origin = tester.getTopLeft(
              find.byKey(const Key('rating-options')),
            );
            return [
              for (final choice in choices.evaluate())
                tester.getRect(find.byWidget(choice.widget)).shift(-origin),
            ];
          }

          final before = positions();
          expect(before.map((rect) => rect.width).toSet(), hasLength(1));
          expect(before.every((rect) => rect.height >= 48), isTrue);
          await tester.tap(selected);
          await tester.pumpAndSettle();
          expect(positions(), before);
          expect(tester.widget<ChoiceChip>(selected).selected, isTrue);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('clock presets and fine adjustment preserve custom values', (
    tester,
  ) async {
    var control = const TimeControl(enabled: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: TimeControlPicker(
                value: control,
                onChanged: (value) => setState(() => control = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('3 + 2'));
    await tester.pumpAndSettle();
    expect(control.minutes, 3);
    expect(control.incrementSeconds, 2);
    await tester.tap(find.byTooltip('Increase Minutes per player'));
    await tester.pumpAndSettle();
    expect(control.minutes, 4);
    await tester.tap(find.byTooltip('Decrease Seconds added per move'));
    await tester.pumpAndSettle();
    expect(control.incrementSeconds, 1);
    await tester.tap(find.text('Unlimited time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(control.minutes, 4);
    expect(control.incrementSeconds, 1);
    expect(control.enabled, isTrue);
  });

  testWidgets('campaign promotes the next challenge above completed levels', (
    tester,
  ) async {
    final levels = [
      _level(600, completed: true),
      _level(800),
      _level(1000, unlocked: false),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          difficultyProgressProvider.overrideWith(
            (ref) => Stream.value(levels),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const CampaignScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 levels completed'), findsOneWidget);
    expect(find.text('Your next challenge'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Play level'), 120);
    final nextCard = find.ancestor(
      of: find.text('Play level'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: nextCard, matching: find.text('Maia-3 800')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Play again'), 120);
    expect(
      tester.getTopLeft(find.text('Maia-3 600')).dy,
      greaterThan(tester.getTopLeft(find.text('Maia-3 800')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'campaign setup remains usable with large text on a narrow screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            difficultyProgressProvider.overrideWith(
              (ref) => Stream.value([_level(600)]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const CampaignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Game setup'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game setup'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Black'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Black'));
      await tester.pumpAndSettle();
      expect(find.text('Black · Unlimited time'), findsOneWidget);
      await tester.ensureVisible(find.text('Clock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clock'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('3 + 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 + 2'));
      await tester.pumpAndSettle();
      expect(find.text('Black · 3 + 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('campaign exposes a retry when progress is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          difficultyProgressProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const CampaignScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No campaign levels are available yet.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

DifficultyProgressModel _level(
  int rating, {
  bool completed = false,
  bool unlocked = true,
}) => DifficultyProgressModel(
  rating: rating,
  validWins: completed ? 2 : 0,
  gamesInWindow: completed ? 2 : 0,
  unlocked: unlocked,
  winsRequired: 2,
  windowSize: 3,
  updatedAtUtc: DateTime.utc(2026),
);
