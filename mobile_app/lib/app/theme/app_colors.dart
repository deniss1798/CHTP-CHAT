import 'package:flutter/material.dart';

/// Минималистичная чёрно-оранжевая палитра: чистый чёрный фон, тёплый акцент, без «сине-серых» пузырей.
class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color backgroundDeep = Color(0xFF010101);
  static const Color backgroundSecondary = Color(0xFF070707);
  static const Color backgroundTertiary = Color(0xFF1A0701);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceSoft = Color(0xFF181818);
  static const Color surfaceRaised = Color(0xFF171311);
  static const Color surfaceGlass = Color(0xEA12100E);
  static const Color surfaceHighlight = Color(0xFF2A160C);

  /// Основной акцент — насыщенный янтарь (не «системный» Apple-orange).
  static const Color accent = Color(0xFFFF5B1F);
  static const Color accentBright = Color(0xFFFF7A3C);
  static const Color accentMuted = Color(0xFF8B3619);
  static const Color accentGlow = Color(0xFFFFA06A);
  static const Color accentBorder = Color(0xFF6E2A14);
  static const Color accentWash = Color(0xFF3B1609);

  /// Свои сообщения: тёплый графит с лёгким оттенком кожи акцента.
  static const Color bubbleMine = Color(0xFF18100D);
  /// Входящие: чуть светлее чистого фона для разделения без «панелей».
  static const Color bubbleOther = Color(0xFF101010);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA4A4A4);
  static const Color textMuted = Color(0xFF737373);
  static const Color textOnAccent = Color(0xFF120A05);

  static const Color error = Color(0xFFFF5C5C);
  static const Color danger = Color(0xFFFF5A5A);
  static const Color dangerSurface = Color(0xFF3C1616);

  static const Color inputFill = Color(0xFF0E0E0E);
  static const Color inputBorder = Color(0xFF512516);
  static const Color strokeSoft = Color(0x17FFFFFF);
  static const Color strokeMedium = Color(0x26FFFFFF);
  static const Color strokeAccent = Color(0xB36E2A14);

  /// Боковая панель (макет десктопа): чистый чёрный, активная «таблетка».
  static const Color navRailBackground = Color(0xFF050505);
  static const Color navRailActivePill = Color(0xFF29170D);
  /// Синхрон с [accent]: насыщенный оранжевый, без «золотисто-жёлтого» #FF8C00.
  static const Color navRailActiveAccent = accent;
  static const Color navRailInactive = Color(0xFF8A8A8A);

  /// Карточка чата и неактивные чипы (макет: ~#1A1A1A).
  static const Color chatListCard = Color(0xFF141414);
}
