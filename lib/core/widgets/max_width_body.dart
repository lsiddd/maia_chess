import 'package:flutter/material.dart';

/// Limita a largura do conteúdo em telas largas (tablets, paisagem),
/// evitando que listas e botões estiquem até a borda. Em telas estreitas
/// o conteúdo já ocupa a largura toda normalmente, então não há efeito
/// visível.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({required this.child, super.key, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
