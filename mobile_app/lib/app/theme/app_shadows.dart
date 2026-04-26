import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Тёплые акцентные тени в стиле референса (orange glow на чёрном фоне).
abstract final class AppShadows {
  AppShadows._();

  /// Плавающая карточка / панель.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withAlpha(190),
          blurRadius: 34,
          offset: const Offset(0, 16),
          spreadRadius: -10,
        ),
        BoxShadow(
          color: AppColors.accent.withAlpha(54),
          blurRadius: 34,
          offset: const Offset(0, 10),
          spreadRadius: -10,
        ),
      ];

  /// Лёгкий подъём списков и тайлов.
  static List<BoxShadow> get lift => [
        BoxShadow(
          color: Colors.black.withAlpha(100),
          blurRadius: 18,
          offset: const Offset(0, 10),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: AppColors.accent.withAlpha(38),
          blurRadius: 22,
          offset: const Offset(0, 4),
          spreadRadius: -8,
        ),
      ];

  /// Кнопка / FAB с оранжевым свечением.
  static List<BoxShadow> accentFab() => [
        BoxShadow(
          color: AppColors.accent.withAlpha(140),
          blurRadius: 40,
          offset: const Offset(0, 12),
          spreadRadius: -1,
        ),
        BoxShadow(
          color: Colors.black.withAlpha(130),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  /// Верхняя кромка (поле ввода чата).
  static List<BoxShadow> get topBar => [
        BoxShadow(
          color: Colors.black.withAlpha(130),
          blurRadius: 28,
          offset: const Offset(0, -8),
          spreadRadius: -6,
        ),
      ];

  /// Первичная кнопка (elevated).
  static List<BoxShadow> get primaryButton => [
        BoxShadow(
          color: AppColors.accent.withAlpha(130),
          blurRadius: 34,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withAlpha(80),
          blurRadius: 12,
          offset: const Offset(0, 8),
        ),
      ];

  /// Snackbar / toast.
  static List<BoxShadow> get floatingSnack => [
        BoxShadow(
          color: Colors.black.withAlpha(112),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get accentStroke => [
        BoxShadow(
          color: AppColors.accent.withAlpha(82),
          blurRadius: 28,
          offset: const Offset(0, 4),
          spreadRadius: -7,
        ),
      ];

  static List<BoxShadow> get orbitGlow => [
        BoxShadow(
          color: AppColors.accent.withAlpha(110),
          blurRadius: 44,
          spreadRadius: -10,
        ),
        BoxShadow(
          color: AppColors.accentGlow.withAlpha(42),
          blurRadius: 70,
          spreadRadius: -24,
        ),
      ];
}
