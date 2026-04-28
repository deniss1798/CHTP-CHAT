import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/widgets/app_surface.dart';

class ChatsAppBar extends StatelessWidget {
  const ChatsAppBar({
    super.key,
    this.onOpenSettings,
  });

  final Future<void> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final hasSettingsAction = onOpenSettings != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _BrandBadge(),
        const Spacer(),
        if (hasSettingsAction)
          AppIconButtonSurface(
            icon: AppIcons.settings,
            tooltip: 'Настройки',
            onTap: onOpenSettings!,
          ),
      ],
    );
  }
}

/// Бейдж «ЧТП ЧАТ» в шапке списка чатов.
class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: AppColors.navRailActiveAccent.withValues(alpha: 0.85),
            width: 1.1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navRailActiveAccent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'ЧТП',
                  style: TextStyle(
                    color: Color(0xFF1A0A00),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'ЧАТ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
