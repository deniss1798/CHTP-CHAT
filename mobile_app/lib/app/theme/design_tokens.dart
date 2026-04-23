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
  static const double xxl = 28;
  static const double pill = 999;
}

/// Компактные контролы: плоские кнопки без «колхозных» полотен.
abstract final class AppSizes {
  static const double btnHeight = 40;
  static const double fab = 56;
  static const double inputAction = 40;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double listAvatar = 48;
  static const double topAction = 44;
}

/// Узкая колонка для форм на широком окне (десктоп / большое окно).
abstract final class AppBreakpoints {
  static const double authPanelMaxWidth = 420;

  /// Вторичные экраны (поиск контакта, подстраницы).
  static const double contentMaxWidth = 520;

  /// Формы с длинными списками (создание группы).
  static const double formPanelMaxWidth = 560;

  /// Карточные экраны (настройки).
  static const double settingsPanelMaxWidth = 440;

  static const double wideLayoutMinWidth = 720;

  /// Два столбца на экране входа: форма слева, визуал справа.
  static const double authSplitLayoutMinWidth = 900;
}

/// Почти плоский фон: лёгкий градиент вниз, без «цветных» полос.
abstract final class AppGradients {
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF090705),
      Color(0xFF000000),
      Color(0xFF0D0603),
    ],
    stops: [0, 0.58, 1],
  );

  static const LinearGradient heroPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF19120F),
      Color(0xFF111111),
      Color(0xFF191008),
    ],
  );

  static const LinearGradient surfacePanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF171412),
      Color(0xFF100F0E),
      Color(0xFF1A1410),
    ],
  );

  static const LinearGradient accentPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF8C55),
      Color(0xFFFF6A2A),
      Color(0xFFE75418),
    ],
  );

  static const LinearGradient selectedPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF22150E),
      Color(0xFF181210),
      Color(0xFF29160C),
    ],
  );

  static const LinearGradient bubbleMine = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF22160F),
      Color(0xFF18110E),
      Color(0xFF28150B),
    ],
  );

  static const LinearGradient bubbleOther = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF161616),
      Color(0xFF0F0F0F),
      Color(0xFF141312),
    ],
  );
}
