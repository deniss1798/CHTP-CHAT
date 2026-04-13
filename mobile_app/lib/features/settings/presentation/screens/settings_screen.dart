import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../core/storage/secure_storage_service.dart';
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
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(10),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  icon: const Icon(AppIcons.back, size: 18),
                ),
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
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? AppSpacing.xxxl : AppSpacing.xxl,
                        vertical: isWide ? 40 : AppSpacing.xxxl,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: Colors.white.withAlpha(14),
                          width: 1,
                        ),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Настройки',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
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
                            leading: const Icon(
                              AppIcons.person,
                              color: AppColors.accent,
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
                            leading: Icon(
                              AppIcons.deleteForever,
                              color: Colors.redAccent,
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
