import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';

class ChatsLoadingState extends StatelessWidget {
  const ChatsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSurface(
        radius: AppRadius.xxl,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2.4,
              ),
            ),
            SizedBox(width: 14),
            Text(
              'Загружаем чаты',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
