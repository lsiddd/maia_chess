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
      );

  CurvedAnimation? _curvedAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = _curvedAnimation ??= CurvedAnimation(
      parent: animation,
      curve: AppMotion.curve,
      reverseCurve: AppMotion.curve.flipped,
    );
    final slide = _slideAnimation ??= Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  void dispose() {
    _curvedAnimation?.dispose();
    super.dispose();
  }
}
