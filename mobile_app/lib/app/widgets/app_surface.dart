import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/design_tokens.dart';

enum AppSurfaceTone {
  base,
  elevated,
  accent,
  selected,
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.xl,
    this.tone = AppSurfaceTone.base,
    this.borderColor,
    this.shadow,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final AppSurfaceTone tone;
  final Color? borderColor;
  final List<BoxShadow>? shadow;

  LinearGradient _gradient() {
    switch (tone) {
      case AppSurfaceTone.elevated:
        return AppGradients.heroPanel;
      case AppSurfaceTone.accent:
        return AppGradients.accentPanel;
      case AppSurfaceTone.selected:
        return AppGradients.selectedPanel;
      case AppSurfaceTone.base:
        return AppGradients.surfacePanel;
    }
  }

  Color _borderColor() {
    if (borderColor != null) return borderColor!;
    switch (tone) {
      case AppSurfaceTone.accent:
        return AppColors.accent.withAlpha(90);
      case AppSurfaceTone.selected:
        return AppColors.accentBorder.withAlpha(170);
      case AppSurfaceTone.base:
      case AppSurfaceTone.elevated:
        return AppColors.strokeSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: _gradient(),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _borderColor(),
          width: 1,
        ),
        boxShadow: shadow ?? AppShadows.card,
      ),
      child: child,
    );
  }
}

class AppIconButtonSurface extends StatelessWidget {
  const AppIconButtonSurface({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = AppSizes.topAction,
    this.iconSize = AppSizes.iconMd,
    this.tooltip,
    this.active = false,
    this.iconColor,
  });

  final IconData icon;
  final FutureOr<void> Function()? onTap;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool active;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                onTap!.call();
              },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: active ? AppGradients.selectedPanel : AppGradients.surfacePanel,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: active
                  ? AppColors.accent.withAlpha(120)
                  : AppColors.strokeSoft,
            ),
            boxShadow: active ? AppShadows.accentStroke : AppShadows.lift,
          ),
          child: Icon(
            icon,
            color: iconColor ??
                (active ? AppColors.accentBright : AppColors.textPrimary),
            size: iconSize,
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class AppPillBadge extends StatelessWidget {
  const AppPillBadge({
    super.key,
    required this.label,
    this.icon,
    this.accent = false,
  });

  final String label;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final background = accent
        ? AppColors.accent.withAlpha(34)
        : AppColors.surfaceGlass;
    final textColor = accent ? AppColors.accentBright : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: accent ? AppColors.accentBorder.withAlpha(170) : AppColors.strokeSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
