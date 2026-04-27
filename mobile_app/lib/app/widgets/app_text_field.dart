import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/design_tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppTextStyles.input,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.inputHint,
        filled: true,
        fillColor: AppColors.chatListCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: AppColors.textMuted, size: AppSizes.iconLg),
        suffixIcon: suffixIcon,
        border: _border(AppColors.accentBorder),
        enabledBorder: _border(AppColors.accent.withValues(alpha: 0.35)),
        focusedBorder: _border(AppColors.accent, width: 1.2),
        disabledBorder: _border(AppColors.strokeSoft),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.showClearButton = true,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool showClearButton;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return AppTextField(
          controller: controller,
          hintText: hintText,
          prefixIcon: AppIcons.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          suffixIcon: showClearButton && value.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Очистить',
                  onPressed: controller.clear,
                  icon: const Icon(
                    AppIcons.close,
                    color: AppColors.textMuted,
                    size: AppSizes.iconMd,
                  ),
                )
              : null,
        );
      },
    );
  }
}
