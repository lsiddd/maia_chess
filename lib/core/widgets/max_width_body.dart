import 'package:flutter/material.dart';

/// Limit content width on tablets and landscape screens so lists and buttons
/// remain readable. Narrow screens use the available width.
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
