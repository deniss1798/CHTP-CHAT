import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Мягкие тени для глубины без «неона» — карточки, FAB, бар ввода.
abstract final class AppShadows {
  AppShadows._();

  /// Плавающая карточка / панель.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withAlpha(170),
          blurRadius: 28,
          offset: const Offset(0, 18),
          spreadRadius: -10,
        ),
        BoxShadow(
          color: AppColors.accent.withAlpha(22),
          blurRadius: 26,
          offset: const Offset(0, 8),
          spreadRadius: -16,
        ),
      ];

  /// Лёгкий подъём списков и тайлов.
  static List<BoxShadow> get lift => [
        BoxShadow(
          color: Colors.black.withAlpha(120),
          blurRadius: 18,
          offset: const Offset(0, 10),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: AppColors.accent.withAlpha(14),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: -12,
        ),
      ];

  /// Кнопка / FAB с оранжевым свечением.
  static List<BoxShadow> accentFab() => [
        BoxShadow(
          color: AppColors.accent.withAlpha(82),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Colors.black.withAlpha(120),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  /// Верхняя кромка (поле ввода чата).
  static List<BoxShadow> get topBar => [
        BoxShadow(
          color: Colors.black.withAlpha(120),
          blurRadius: 24,
          offset: const Offset(0, -8),
          spreadRadius: -8,
        ),
      ];

  /// Первичная кнопка (elevated).
  static List<BoxShadow> get primaryButton => [
        BoxShadow(
          color: AppColors.accent.withAlpha(62),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withAlpha(70),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ];

  /// Snackbar / toast.
  static List<BoxShadow> get floatingSnack => [
        BoxShadow(
          color: Colors.black.withAlpha(100),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get accentStroke => [
        BoxShadow(
          color: AppColors.accent.withAlpha(28),
          blurRadius: 18,
          offset: const Offset(0, 4),
          spreadRadius: -10,
        ),
      ];
}
