import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/design_tokens.dart';

enum AppButtonVariant {
  primary,
  secondary,
  danger,
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.height = AppSizes.btnLgHeight,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final double height;

  Color get _background {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.accent;
      case AppButtonVariant.secondary:
        return AppColors.surfaceHighlight;
      case AppButtonVariant.danger:
        return AppColors.dangerSurface;
    }
  }

  Color get _foreground {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.textOnAccent;
      case AppButtonVariant.secondary:
        return AppColors.accentBright;
      case AppButtonVariant.danger:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        onPressed: enabled ? () => onPressed!.call() : null,
        icon: isLoading
            ? SizedBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(_foreground),
                ),
              )
            : Icon(icon ?? AppIcons.check, size: AppSizes.iconMd),
        label: Text(label, style: AppTextStyles.button.copyWith(color: _foreground)),
        style: FilledButton.styleFrom(
          backgroundColor: _background,
          foregroundColor: _foreground,
          disabledBackgroundColor: _background.withValues(alpha: 0.55),
          disabledForegroundColor: _foreground.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}
