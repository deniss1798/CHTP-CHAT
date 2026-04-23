import 'package:flutter/material.dart';

/// Минималистичная чёрно-оранжевая палитра: чистый чёрный фон, тёплый акцент, без «сине-серых» пузырей.
class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color backgroundDeep = Color(0xFF040404);
  static const Color backgroundSecondary = Color(0xFF0A0A0A);
  static const Color backgroundTertiary = Color(0xFF120C09);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceSoft = Color(0xFF181818);
  static const Color surfaceRaised = Color(0xFF161210);
  static const Color surfaceGlass = Color(0xCC14100E);
  static const Color surfaceHighlight = Color(0xFF211915);

  /// Основной акцент — насыщенный янтарь (не «системный» Apple-orange).
  static const Color accent = Color(0xFFFF6A2A);
  static const Color accentBright = Color(0xFFFF8F57);
  static const Color accentMuted = Color(0xFF8A4C2D);
  static const Color accentGlow = Color(0xFFFFB288);
  static const Color accentBorder = Color(0xFF4A2A18);
  static const Color accentWash = Color(0xFF2B1810);

  /// Свои сообщения: тёплый графит с лёгким оттенком кожи акцента.
  static const Color bubbleMine = Color(0xFF161210);
  /// Входящие: чуть светлее чистого фона для разделения без «панелей».
  static const Color bubbleOther = Color(0xFF0E0E0E);

  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFF9B9B9B);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color textOnAccent = Color(0xFF120A05);

  static const Color error = Color(0xFFFF5C5C);

  static const Color inputFill = Color(0xFF0D0D0D);
  static const Color inputBorder = Color(0xFF2A1A12);
  static const Color strokeSoft = Color(0x14FFFFFF);
  static const Color strokeMedium = Color(0x1FFFFFFF);
  static const Color strokeAccent = Color(0x4D4A2A18);

  /// Боковая панель (макет десктопа): чистый чёрный, активная «таблетка».
  static const Color navRailBackground = Color(0xFF000000);
  static const Color navRailActivePill = Color(0xFF2C1A0A);
  /// Синхрон с [accent]: насыщенный оранжевый, без «золотисто-жёлтого» #FF8C00.
  static const Color navRailActiveAccent = accent;
  static const Color navRailInactive = Color(0xFF8E8E8E);

  /// Карточка чата и неактивные чипы (макет: ~#1A1A1A).
  static const Color chatListCard = Color(0xFF1A1A1A);
}
