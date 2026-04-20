import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
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
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= AppBreakpoints.wideLayoutMinWidth;
    final cardMaxWidth = isWide ? 440.0 : double.infinity;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 8,
              child: AppIconButtonSurface(
                icon: AppIcons.back,
                tooltip: 'Назад',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? AppSpacing.xxxl : AppSpacing.xxl,
                    vertical: AppSpacing.xxxl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    child: AppSurface(
                      tone: AppSurfaceTone.elevated,
                      radius: AppRadius.xxl,
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? AppSpacing.xxxl : AppSpacing.xxl,
                        vertical: isWide ? 40 : AppSpacing.xxxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Center(
                            child: AppPillBadge(
                              label: 'SYSTEM PREFERENCES',
                              accent: true,
                            ),
                          ),
                          SizedBox(height: isWide ? 24 : AppSpacing.xl),
                          Text(
                            'Аккаунт',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: isWide ? 20 : 18,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: isWide ? 28 : AppSpacing.xl),
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
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                boxShadow: AppShadows.primaryButton,
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
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: Colors.redAccent.withAlpha(70)),
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
                  ),
                ),
              ),
            ),
          ],
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
