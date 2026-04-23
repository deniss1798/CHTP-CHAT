import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_content_frame.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../calls/data/ice_config_service.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../profile/data/services/profile_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// Во вкладке [MessengerDesktopShell] без кнопки «Назад».
  final bool embedded;

  static const Color _dangerZoneIconBg = Color(0xFF3D1919);
  static const Color _dangerText = Color(0xFFFF4B4B);
  static const Color _dangerIcon = Color(0xFFFF4B4B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            child: AppContentFrame(
              maxWidth: AppBreakpoints.settingsPanelMaxWidth,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!embedded) ...[
                        AppIconButtonSurface(
                          icon: AppIcons.back,
                          tooltip: 'Назад',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                      ],
                      const Expanded(
                        child: Text(
                          'Настройки',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Управляйте своим аккаунтом и безопасностью.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Аккаунт',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppSurface(
                    tone: AppSurfaceTone.elevated,
                    radius: AppRadius.xl,
                    padding: EdgeInsets.zero,
                    child: _settingsTile(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          AppIcons.person,
                          color: AppColors.textOnAccent,
                          size: 24,
                        ),
                      ),
                      title: 'Мой профиль',
                      subtitle: 'Управление личными данными и профилем',
                      titleColor: AppColors.textPrimary,
                      subtitleColor: AppColors.textSecondary,
                      trailing: Icon(
                        AppIcons.chevronRight,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Опасная зона',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppSurface(
                    tone: AppSurfaceTone.elevated,
                    radius: AppRadius.xl,
                    padding: EdgeInsets.zero,
                    child: _settingsTile(
                      onTap: () => _confirmDeleteAccount(context),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _dangerZoneIconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          AppIcons.delete,
                          color: _dangerIcon,
                          size: 24,
                        ),
                      ),
                      title: 'Удалить аккаунт',
                      subtitle:
                          'Безвозвратное удаление аккаунта и всех данных',
                      titleColor: _dangerText,
                      subtitleColor: AppColors.textSecondary,
                      trailing: Icon(
                        AppIcons.chevronRight,
                        color: _dangerText.withValues(alpha: 0.9),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required Widget leading,
    required String title,
    String? subtitle,
    required Color titleColor,
    Color? subtitleColor,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subtitleColor ?? AppColors.textSecondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Удалить аккаунт?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Все ваши данные и сообщения будут безвозвратно удалены.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: _dangerText),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final service = ProfileService();

    try {
      await service.deleteMyAccount();
      IceConfigService.instance.clearCache();
      await SecureStorageService.deleteAccessToken();
      if (!context.mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      String msg = 'Не удалось удалить аккаунт';
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map) {
          msg = d['detail']?.toString() ?? msg;
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
