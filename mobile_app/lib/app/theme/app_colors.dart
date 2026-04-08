import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF09090B);
  static const Color backgroundSecondary = Color(0xFF111214);
  static const Color surface = Color(0xFF1A1B1F);
  static const Color surfaceSoft = Color(0xFF23252B);

  static const Color accent = Color(0xFFFF8A00);
  static const Color accentBright = Color(0xFFFF9F1A);
  static const Color accentBorder = Color(0xFF7A4A12);

  /// Свои сообщения в чате: тёмный нейтральный фон под твой оранжевый акцент (кнопки, индикаторы)
  static const Color bubbleMine = Color(0xFF2A3140);
  /// Чужие сообщения — как surface, без отдельной «чужой» гаммы
  static const Color bubbleOther = Color(0xFF1A1B1F);

  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF98A2B3);
  static const Color textMuted = Color(0xFF667085);

  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5C5C);

  static const Color inputFill = Color(0xFF1A1C20);
  static const Color inputBorder = Color(0xFF3A2A17);
}
