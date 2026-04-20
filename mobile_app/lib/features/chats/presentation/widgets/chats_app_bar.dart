import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';

class ChatsAppBar extends StatelessWidget {
  const ChatsAppBar({
    super.key,
    required this.chatCount,
    required this.onOpenSettings,
    required this.onLogout,
  });

  final int chatCount;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ЧТП',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(10),
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: () {
                onOpenSettings();
              },
              icon: const Icon(AppIcons.settings),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(10),
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: () {
                onLogout();
              },
              icon: const Icon(AppIcons.logout),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Сообщения',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$chatCount чатов',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
