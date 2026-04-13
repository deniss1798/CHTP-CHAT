import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Плоский тёмный фон с одним мягким «ореолом» — без визуального шума.
class AppScreenBackground extends StatelessWidget {
  const AppScreenBackground({
    super.key,
    required this.child,
    this.showAmbientGlow = true,
  });

  final Widget child;
  final bool showAmbientGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.background,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showAmbientGlow)
            Positioned(
              top: -40,
              right: -80,
              child: _AmbientBlob(
                size: 280,
                color: AppColors.accent.withAlpha(14),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.5,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }
}
