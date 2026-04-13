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
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
}

/// Компактные контролы: плоские кнопки без «колхозных» полотен.
abstract final class AppSizes {
  static const double btnHeight = 40;
  static const double fab = 56;
  static const double inputAction = 40;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double listAvatar = 48;
}

/// Узкая колонка для форм на широком окне (десктоп / большое окно).
abstract final class AppBreakpoints {
  static const double authPanelMaxWidth = 420;
  static const double wideLayoutMinWidth = 720;
}

/// Почти плоский фон: лёгкий градиент вниз, без «цветных» полос.
abstract final class AppGradients {
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF050505),
      Color(0xFF000000),
      Color(0xFF080402),
    ],
  );
}
