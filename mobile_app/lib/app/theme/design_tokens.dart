import 'package:flutter/material.dart';

/// Сетка 4pt, скругления и градиенты — единый язык интерфейса.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

/// Узкая колонка для форм на широком окне (десктоп / большое окно).
abstract final class AppBreakpoints {
  static const double authPanelMaxWidth = 420;
  static const double wideLayoutMinWidth = 720;
}

/// Фон экранов — ваши исходные цвета градиента.
abstract final class AppGradients {
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0B0B0D),
      Color(0xFF09090B),
      Color(0xFF140A02),
    ],
  );
}
