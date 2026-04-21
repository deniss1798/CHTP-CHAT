import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Центрирует контент и ограничивает ширину на больших экранах — единая сетка для подстраниц.
class AppContentFrame extends StatelessWidget {
  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final pad = padding ??
        const EdgeInsets.symmetric(horizontal: AppSpacing.xxl);

    return Padding(
      padding: pad,
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
