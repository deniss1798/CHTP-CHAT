import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';

class ChatsAppBar extends StatelessWidget {
  const ChatsAppBar({
    super.key,
    required this.onOpenSettings,
    required this.onLogout,
  });

  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withAlpha(120),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'ЧТП ЧАТ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Сообщения',
                    style: textTheme.headlineLarge?.copyWith(
                      fontSize: 36,
                      height: 1.02,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Все переписки и звонки в одном месте.',
                    style: TextStyle(
                      color: AppColors.textSecondary.withAlpha(210),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppIconButtonSurface(
              icon: AppIcons.settings,
              tooltip: 'Настройки',
              onTap: onOpenSettings,
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIconButtonSurface(
              icon: AppIcons.logout,
              tooltip: 'Выйти',
              onTap: onLogout,
            ),
          ],
        ),
      ],
    );
  }
}
