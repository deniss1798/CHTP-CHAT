import 'package:flutter/material.dart';

/// Сетка 4pt, скругления и градиенты — единый язык интерфейса.
abstract final class AppSpacing {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 30;
  static const double huge = 40;
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 30;
  static const double pill = 999;
}

/// Компактные контролы: плоские кнопки без «колхозных» полотен.
abstract final class AppSizes {
  static const double btnSmHeight = 40;
  static const double btnHeight = 44;
  static const double btnLgHeight = 52;
  static const double fab = 56;
  static const double inputAction = 42;
  static const double inputHeight = 52;
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
      Color(0xFF130501),
      Color(0xFF000000),
      Color(0xFF1E0701),
    ],
    stops: [0, 0.58, 1],
  );

  static const LinearGradient heroPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF23140E),
      Color(0xFF121212),
      Color(0xFF271107),
    ],
  );

  static const LinearGradient surfacePanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1D1713),
      Color(0xFF111111),
      Color(0xFF21120C),
    ],
  );

  static const LinearGradient accentPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF8A4A),
      Color(0xFFFF5B1F),
      Color(0xFFFF3F0A),
    ],
  );

  static const LinearGradient selectedPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF32180E),
      Color(0xFF171312),
      Color(0xFF341205),
    ],
  );

  static const LinearGradient bubbleMine = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF25140D),
      Color(0xFF151211),
      Color(0xFF2A1107),
    ],
  );

  static const LinearGradient bubbleOther = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF191919),
      Color(0xFF111111),
      Color(0xFF161413),
    ],
  );
}
