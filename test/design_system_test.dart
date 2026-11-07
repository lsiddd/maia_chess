import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maia_chess/core/theming/app_page_route.dart';
import 'package:maia_chess/core/theming/app_theme.dart';
import 'package:maia_chess/core/widgets/max_width_body.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/settings_repository.dart';
import 'package:maia_chess/main.dart';

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.dark : AppTheme.light;
    test('semantic text colours meet WCAG AA, dark=$dark', () {
      final colors = theme.colorScheme;
      final pairs = [
        (colors.onSurface, colors.surface),
        (colors.onSurfaceVariant, colors.surface),
        (colors.onSurface, theme.scaffoldBackgroundColor),
        (colors.onPrimary, colors.primary),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (colors.onSecondaryContainer, colors.secondaryContainer),
        (colors.onErrorContainer, colors.errorContainer),
      ];
      for (final (foreground, background) in pairs) {
        final a = foreground.computeLuminance();
        final b = background.computeLuminance();
        final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }
    });
    testWidgets('home stays navigable at 320px and 200% text, dark=$dark', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeGameProvider.overrideWith((ref) => Stream.value(null)),
            appSettingsProvider.overrideWith(
              (ref) => Stream.value(const StoredAppSettings()),
            ),
          ],
          child: MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24),
              ),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Saved games and PGN'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved games and PGN').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('content clears side and bottom system insets', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(800, 600),
            padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
          ),
          child: MaxWidthBody(child: SizedBox.expand(key: Key('content'))),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(const Key('content')));
    expect(rect.left, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(776));
    expect(rect.bottom, lessThanOrEqualTo(568));
  });

  testWidgets(
    'reduced motion exposes destination without a visual transition',
    (tester) async {
      late BuildContext navigationContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              navigationContext = context;
              return const Scaffold(body: Text('Origin'));
            },
          ),
        ),
      );
      Navigator.of(navigationContext).push(
        AppPageRoute(builder: (_) => const Scaffold(body: Text('Destination'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Destination').hitTestable(), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Destination'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Origin'), findsOneWidget);
    },
  );
}
