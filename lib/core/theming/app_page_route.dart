import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared fade and slight horizontal slide for navigation between app
/// screens. Use `AppPageRoute(builder: ...)` to keep transitions consistent.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionDuration: AppMotion.medium,
        reverseTransitionDuration: AppMotion.medium,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.curve,
            reverseCurve: AppMotion.curve.flipped,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
