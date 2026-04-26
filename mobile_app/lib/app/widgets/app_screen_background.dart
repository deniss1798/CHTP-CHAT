import 'dart:math' as math;

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
              top: -95,
              right: -120,
              child: _AmbientBlob(
                size: 420,
                color: AppColors.accent.withAlpha(42),
              ),
            ),
          if (showAmbientGlow)
            Positioned(
              top: 96,
              left: -150,
              child: _AmbientBlob(
                size: 340,
                color: AppColors.accentBright.withAlpha(24),
              ),
            ),
          if (showAmbientGlow)
            Positioned(
              bottom: -140,
              right: MediaQuery.sizeOf(context).width * 0.12,
              child: _AmbientBlob(
                size: 360,
                color: AppColors.accent.withAlpha(28),
              ),
            ),
          if (showAmbientGlow)
            const Positioned(
              top: 74,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: _ReferenceOrbitPainter(),
                  ),
                ),
              ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent.withAlpha(14),
                    Colors.transparent,
                    Colors.black.withAlpha(42),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ReferenceOrbitPainter extends CustomPainter {
  const _ReferenceOrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.accent.withAlpha(34);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = AppColors.accent.withAlpha(50);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.16);
    for (final scale in const [1.0, 0.72]) {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.58 * scale,
        height: 78 * scale,
      );
      canvas.drawOval(rect, glow);
      canvas.drawOval(rect, stroke);
    }

    final dotPaint = Paint()..color = AppColors.accentBright;
    for (final data in const [
      (angle: 0.18, radius: 0.31),
      (angle: math.pi + 0.08, radius: 0.27),
      (angle: 5.2, radius: 0.21),
    ]) {
      final dx = math.cos(data.angle) * size.width * data.radius;
      final dy = math.sin(data.angle) * 38;
      canvas.drawCircle(Offset(dx, dy), 2.2, dotPaint);
      canvas.drawCircle(
        Offset(dx, dy),
        7.5,
        Paint()
          ..color = AppColors.accent.withAlpha(46)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
