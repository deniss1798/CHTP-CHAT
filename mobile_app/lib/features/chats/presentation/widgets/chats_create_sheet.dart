import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';

class ChatsCreateSheet {
  const ChatsCreateSheet._();

  static const double _wideBreakpoint = 480;

  static Future<String?> show(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= _wideBreakpoint) {
      return showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (ctx) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
                minWidth: 320,
              ),
              child: const _ChatsCreateBody(isDialog: true),
            ),
          );
        },
      );
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return const _ChatsCreateBody(isDialog: false);
      },
    );
  }
}

class _ChatsCreateBody extends StatelessWidget {
  const _ChatsCreateBody({required this.isDialog});

  final bool isDialog;

  @override
  Widget build(BuildContext context) {
    final child = AppSurface(
      tone: AppSurfaceTone.elevated,
      radius: AppRadius.xxl,
      padding: EdgeInsets.fromLTRB(
        20,
        isDialog ? 18 : 12,
        20,
        22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDialog) ...[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const _Header(),
          const SizedBox(height: 8),
          _CreateChatOption(
            selected: true,
            icon: AppIcons.person,
            title: 'Личный',
            subtitle: 'С одним собеседником',
            onTap: () => Navigator.of(context).pop('private'),
          ),
          const SizedBox(height: 10),
          _CreateChatOption(
            selected: false,
            icon: AppIcons.group,
            title: 'Группа',
            subtitle: 'Несколько участников',
            onTap: () => Navigator.of(context).pop('group'),
          ),
        ],
      ),
    );

    if (isDialog) {
      return Material(
        color: Colors.transparent,
        child: child,
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    );
    return Row(
      children: [
        const SizedBox(
          width: 40,
          height: 40,
        ),
        const Expanded(
          child: Text(
            'Новый чат',
            textAlign: TextAlign.center,
            style: titleStyle,
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              customBorder: const CircleBorder(),
              child: const Icon(
                AppIcons.close,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateChatOption extends StatelessWidget {
  const _CreateChatOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderColor: selected ? AppColors.accent : AppColors.strokeSoft,
          shadow: null,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent,
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
                        letterSpacing: -0.2,
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
