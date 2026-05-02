import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';

/// Крупный логотип «ЧТП / ЧАТ» + подзаголовок. [scale] — относительный размер (1.0 = правая колонка).
class AuthHeroBrandingContent extends StatelessWidget {
  const AuthHeroBrandingContent({
    super.key,
    this.scale = 1.0,
    this.showTopAccentLine = false,
    this.compact = false,
  });

  final double scale;
  final bool showTopAccentLine;

  /// Без «пьедестала» с glow — для встраивания под приветствие на мобилке.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final titleSize = 72 * s;
    final subSize = (14 * s).clamp(11.0, 15.0);
    final gapAfterTitle = compact ? 10 * s : 18 * s;

    Widget core = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          Container(
            width: 200 * s,
            height: 10 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 28 * s,
                  spreadRadius: 2 * s,
                ),
              ],
            ),
          ),
          SizedBox(height: 6 * s),
          Container(
            width: 150 * s,
            height: 5 * s,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 28 * s),
        ] else
          SizedBox(height: 2 * s),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF9B6A),
                AppColors.accent,
                Color(0xFFE75418),
              ],
            ).createShader(rect);
          },
          child: Text(
            'ЧТП',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 0.95,
              letterSpacing: -1.2 * s,
            ),
          ),
        ),
        Text(
          'ЧАТ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 0.95,
            letterSpacing: 2.4 * s,
          ),
        ),
        SizedBox(height: gapAfterTitle),
        Text(
          'Сообщения и звонки',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.9),
            fontSize: subSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    core = FittedBox(
      fit: BoxFit.scaleDown,
      child: core,
    );

    if (showTopAccentLine) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: 8 * s, bottom: 4 * s),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.accent.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
        ),
        child: core,
      );
    }

    return core;
  }
}

/// Правая колонка на широком экране.
class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF020202),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.background,
                    const Color(0xFF0C0704),
                    const Color(0xFF150A05).withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: 40,
            child: _GlowBlob(
              size: 200,
              color: AppColors.accent.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth * 0.88;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxW.clamp(200, 420),
                    ),
                    child: const AuthHeroBrandingContent(scale: 1.0),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
              blurRadius: size * 0.5,
            ),
            ...AppShadows.card,
          ],
        ),
      ),
    );
  }
}
