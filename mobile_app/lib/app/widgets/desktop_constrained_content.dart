import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Центрирует контент и ограничивает ширину на десктопе (не «растягивает» мобильную вёрстку).
class DesktopConstrainedContent extends StatelessWidget {
  const DesktopConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.authPanelMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final usable = math.max(0.0, w - AppSpacing.xxl * 2);
    final effective = math.min(maxWidth, usable);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effective),
        child: child,
      ),
    );
  }
}
