import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'app_surface.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.tone = AppSurfaceTone.base,
    this.radius = AppRadius.xl,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AppSurfaceTone tone;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      tone: tone,
      radius: radius,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}
