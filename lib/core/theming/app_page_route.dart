import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Transição única para toda navegação entre telas do app: fade + slide
/// horizontal leve (Material Motion), no lugar da transição padrão da
/// plataforma que cada `MaterialPageRoute` usava isoladamente antes.
///
/// Não altera nenhum fluxo de navegação, só a transição visual; troque
/// `MaterialPageRoute(builder: ...)` por `AppPageRoute(builder: ...)`.
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
