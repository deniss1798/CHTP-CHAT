import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ChatsEmptyState extends StatelessWidget {
  const ChatsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Чаты не найдены',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
        ),
      ),
    );
  }
}
