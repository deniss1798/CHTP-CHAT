import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
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
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          safeUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                chatDetailBuildInitials(title),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
      );
    } else {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          chatDetailBuildInitials(title),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
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
      return ClipOval(
        child: Image.network(
          safeUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                chatDetailBuildInitials(title),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        chatDetailBuildInitials(title),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
