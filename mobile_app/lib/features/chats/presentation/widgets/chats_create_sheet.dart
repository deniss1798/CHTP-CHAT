import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';

class ChatsCreateSheet {
  const ChatsCreateSheet._();

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: AppSurface(
              tone: AppSurfaceTone.elevated,
              radius: AppRadius.xxl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withAlpha(140),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Новый чат',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CreateChatOption(
                    icon: AppIcons.person,
                    title: 'Личный',
                    subtitle: 'С одним собеседником',
                    onTap: () => Navigator.of(context).pop('private'),
                  ),
                  const SizedBox(height: 10),
                  _CreateChatOption(
                    icon: AppIcons.group,
                    title: 'Группа',
                    subtitle: 'Несколько участников',
                    onTap: () => Navigator.of(context).pop('group'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CreateChatOption extends StatelessWidget {
  const _CreateChatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AppSurface(
          radius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.lg),
          shadow: AppShadows.lift,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppGradients.accentPanel,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryButton,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: AppColors.textOnAccent,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                AppIcons.chevronRight,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
