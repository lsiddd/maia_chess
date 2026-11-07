import 'package:flutter/material.dart';

/// Material routes keep Android's predictive back gesture and platform focus
/// handling. Reduced motion skips the visual transition without changing history.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({required super.builder, super.settings});

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
