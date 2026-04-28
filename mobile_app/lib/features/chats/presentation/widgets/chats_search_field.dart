import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';

class ChatsSearchField extends StatelessWidget {
  const ChatsSearchField({
    super.key,
    required this.onChanged,
    this.focusNode,
    this.showShortcutHint = false,
    this.onTapOutside,
  });

  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool showShortcutHint;
  /// Тап вне поля (как в Telegram) — закрыть строку поиска.
  final VoidCallback? onTapOutside;

  String _shortcutLabel() {
    if (kIsWeb) return 'Ctrl+K';
    return defaultTargetPlatform == TargetPlatform.macOS ? '⌘K' : 'Ctrl+K';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171717), Color(0xFF111111), Color(0xFF17100C)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl + 2),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(30),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: TextField(
        focusNode: focusNode,
        onChanged: onChanged,
        onTapOutside: (_) => onTapOutside?.call(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Поиск по чатам',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide.none,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(
            AppIcons.search,
            color: AppColors.textMuted,
            size: 22,
          ),
          suffix: showShortcutHint
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      _shortcutLabel(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
