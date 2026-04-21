import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
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
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                    children: [
                      AppIconButtonSurface(
                        icon: AppIcons.back,
                        tooltip: 'Назад',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Настройки',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppSurface(
                    tone: AppSurfaceTone.elevated,
                    radius: AppRadius.xxl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: AppGradients.accentPanel,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.lift,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              AppIcons.person,
                              color: AppColors.textOnAccent,
                            ),
                          ),
                          title: const Text(
                            'Мой профиль',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            AppIcons.chevronRight,
                            color: AppColors.textMuted.withAlpha(180),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            height: 1,
                            color: AppColors.accentBorder.withAlpha(60),
                          ),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha(28),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: Colors.redAccent.withAlpha(70),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              AppIcons.deleteForever,
                              color: Colors.redAccent,
                            ),
                          ),
                          title: const Text(
                            'Удалить аккаунт',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => _confirmDeleteAccount(context),
                        ),
                      ],
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
              style: TextStyle(color: Colors.redAccent),
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
