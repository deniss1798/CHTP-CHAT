import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../domain/chat_list_rules.dart';
import '../models/chat_list_item_model.dart';

class ChatListItem extends StatelessWidget {
  const ChatListItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  final ChatListItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = item.unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: item.isSelected
                ? AppColors.accent.withAlpha(22)
                : (isUnread
                    ? AppColors.accent.withAlpha(10)
                    : AppColors.surface),
            border: Border.all(
              color: item.isSelected
                  ? AppColors.accent.withAlpha(160)
                  : Colors.white.withAlpha(isUnread ? 10 : 8),
              width: 1,
            ),
            boxShadow: AppShadows.lift,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isUnread)
                  Container(
                    width: 4,
                    color: AppColors.accent,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChatListAvatar(
                          title: item.title,
                          avatarUrl: item.avatarUrl,
                          showOnlineDot: item.isOnline,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: isUnread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: item.isTyping
                                        ? AppColors.accent
                                        : (isUnread
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary),
                                    fontSize: 14,
                                    fontStyle: item.isTyping
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.timeLabel.isNotEmpty)
                              Text(
                                item.timeLabel,
                                style: TextStyle(
                                  color: isUnread
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (item.unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: AppShadows.primaryButton,
                                ),
                                child: Text(
                                  item.unreadCount > 99
                                      ? '99+'
                                      : item.unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatListAvatar extends StatelessWidget {
  const _ChatListAvatar({
    required this.title,
    required this.avatarUrl,
    required this.showOnlineDot,
  });

  final String title;
  final String? avatarUrl;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final safeUrl = (avatarUrl ?? '').trim();

    Widget inner;
    if (safeUrl.isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          safeUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _AvatarFallback(title: title, size: size);
          },
        ),
      );
    } else {
      inner = _AvatarFallback(title: title, size: size);
    }

    if (!showOnlineDot) return inner;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        inner,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.title,
    required this.size,
  });

  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        resolveTitleInitials(title),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
