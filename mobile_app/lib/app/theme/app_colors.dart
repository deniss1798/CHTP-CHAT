import 'package:flutter/material.dart';

/// Минималистичная чёрно-оранжевая палитра: чистый чёрный фон, тёплый акцент, без «сине-серых» пузырей.
class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color backgroundSecondary = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceSoft = Color(0xFF181818);

  /// Основной акцент — насыщенный янтарь (не «системный» Apple-orange).
  static const Color accent = Color(0xFFFF6A2A);
  static const Color accentBright = Color(0xFFFF8F57);
  static const Color accentBorder = Color(0xFF4A2A18);

  /// Свои сообщения: тёплый графит с лёгким оттенком кожи акцента.
  static const Color bubbleMine = Color(0xFF161210);
  /// Входящие: чуть светлее чистого фона для разделения без «панелей».
  static const Color bubbleOther = Color(0xFF0E0E0E);

  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFF9B9B9B);
  static const Color textMuted = Color(0xFF6B6B6B);

  static const Color error = Color(0xFFFF5C5C);

  static const Color inputFill = Color(0xFF0D0D0D);
  static const Color inputBorder = Color(0xFF2A1A12);
}
