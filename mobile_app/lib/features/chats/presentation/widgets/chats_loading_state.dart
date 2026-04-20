import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ChatsLoadingState extends StatelessWidget {
  const ChatsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accent,
      ),
    );
  }
}
