import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../chat_detail_formatters.dart';

class ChatDetailSquareAvatar extends StatelessWidget {
  const ChatDetailSquareAvatar({
    super.key,
    required this.title,
    required this.avatarUrl,
    this.size = 42,
    this.showOnlineDot = false,
  });

  final String title;
  final String? avatarUrl;
  final double size;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    final safeUrl = chatDetailNormalizedAvatarUrl(avatarUrl);

    Widget inner;

    if (safeUrl != null && safeUrl.isNotEmpty) {
      inner = Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          gradient: AppGradients.surfacePanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.strokeSoft),
          boxShadow: AppShadows.lift,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            safeUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _squareFallback(title);
            },
          ),
        ),
      );
    } else {
      inner = _squareFallback(title);
    }

    if (!showOnlineDot) return inner;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        inner,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _squareFallback(String value) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.accentPanel,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.primaryButton,
      ),
      alignment: Alignment.center,
      child: Text(
        chatDetailBuildInitials(value),
        style: const TextStyle(
          color: AppColors.textOnAccent,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatDetailCircleAvatar extends StatelessWidget {
  const ChatDetailCircleAvatar({
    super.key,
    required this.title,
    required this.avatarUrl,
    this.size = 34,
  });

  final String title;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeUrl = chatDetailNormalizedAvatarUrl(avatarUrl);

    if (safeUrl != null && safeUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.surfacePanel,
          border: Border.all(color: AppColors.strokeSoft),
          boxShadow: AppShadows.lift,
        ),
        child: ClipOval(
          child: Image.network(
            safeUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _circleFallback(),
          ),
        ),
      );
    }

    return _circleFallback();
  }

  Widget _circleFallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppGradients.accentPanel,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        chatDetailBuildInitials(title),
        style: const TextStyle(
          color: AppColors.textOnAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
