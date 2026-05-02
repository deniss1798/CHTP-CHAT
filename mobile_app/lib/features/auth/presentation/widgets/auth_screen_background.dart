import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Фон окна входа: глубокий чёрный, оранжевый «нег» справа, слабые иконки-водяные знаки.
class AuthScreenBackground extends StatelessWidget {
  const AuthScreenBackground({
    super.key,
    required this.child,
    this.strengthenRightGlow = false,
  });

  final Widget child;
  final bool strengthenRightGlow;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -w * 0.08,
            top: -60,
            child: _GlowBlob(
              size: 280 + (w * 0.04).clamp(0, 60),
              color: AppColors.accent.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            right: strengthenRightGlow ? -w * 0.02 : w * 0.02,
            top: 0,
            bottom: 0,
            width: w * 0.52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.15, -0.15),
                  radius: 1.15,
                  colors: [
                    AppColors.accent.withValues(
                        alpha: strengthenRightGlow ? 0.2 : 0.11),
                    AppColors.accent.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _GlowBlob(
              size: 360,
              color: AppColors.accentBright.withValues(alpha: 0.05),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _AuthVignettePainter(),
            ),
          ),
          ..._faintIconLayer(size),
          child,
        ],
      ),
    );
  }
}

List<Widget> _faintIconLayer(Size size) {
  const icons = <IconData>[
    Icons.lock_outline_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.settings_outlined,
    Icons.groups_2_outlined,
    Icons.videocam_outlined,
    Icons.shield_outlined,
    Icons.mail_outline_rounded,
    Icons.wifi_tethering_rounded,
  ];
  return List<Widget>.generate(14, (i) {
    final x = (i * 71.0 + i * 13.0) % (size.width * 0.88);
    final y = (i * 97.0 + 17 * i) % (size.height * 0.82);
    return Positioned(
      left: x,
      top: y + 24,
      child: Icon(
        icons[i % icons.length],
        size: 22.0 + (i % 4) * 3,
        color: AppColors.accent.withValues(
          alpha: 0.045 + (i % 3) * 0.018,
        ),
      ),
    );
  });
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

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
              blurRadius: size * 0.45,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthVignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final g = RadialGradient(
      center: Alignment.center,
      radius: 1.15,
      colors: [
        Colors.transparent,
        AppColors.background.withValues(alpha: 0.4),
        AppColors.background.withValues(alpha: 0.75),
      ],
      stops: const [0.4, 0.82, 1],
    );
    final paint = Paint()..shader = g.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
