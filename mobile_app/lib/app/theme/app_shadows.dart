import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Мягкие тени для глубины без «неона» — карточки, FAB, бар ввода.
abstract final class AppShadows {
  AppShadows._();

  /// Плавающая карточка / панель.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withAlpha(140),
          blurRadius: 20,
          offset: const Offset(0, 10),
          spreadRadius: -4,
        ),
      ];

  /// Лёгкий подъём списков и тайлов.
  static List<BoxShadow> get lift => [
        BoxShadow(
          color: Colors.black.withAlpha(90),
          blurRadius: 12,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
      ];

  /// Кнопка / FAB с оранжевым свечением.
  static List<BoxShadow> accentFab() => [
        BoxShadow(
          color: AppColors.accent.withAlpha(55),
          blurRadius: 22,
          offset: const Offset(0, 10),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Colors.black.withAlpha(100),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  /// Верхняя кромка (поле ввода чата).
  static List<BoxShadow> get topBar => [
        BoxShadow(
          color: Colors.black.withAlpha(120),
          blurRadius: 16,
          offset: const Offset(0, -4),
          spreadRadius: -8,
        ),
      ];

  /// Первичная кнопка (elevated).
  static List<BoxShadow> get primaryButton => [
        BoxShadow(
          color: AppColors.accent.withAlpha(40),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withAlpha(50),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Snackbar / toast.
  static List<BoxShadow> get floatingSnack => [
        BoxShadow(
          color: Colors.black.withAlpha(100),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}
