import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';
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
    final selected = item.isSelected;
    final subtitleColor = item.isTyping
        ? AppColors.accentBright
        : (isUnread ? AppColors.textPrimary : AppColors.textSecondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AppSurface(
          radius: AppRadius.xl,
          tone: selected
              ? AppSurfaceTone.selected
              : (isUnread ? AppSurfaceTone.elevated : AppSurfaceTone.base),
          borderColor: selected
              ? AppColors.accent.withAlpha(140)
              : (isUnread
                  ? AppColors.accentBorder.withAlpha(120)
                  : AppColors.strokeSoft),
          shadow: selected ? [...AppShadows.card, ...AppShadows.accentStroke] : AppShadows.lift,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChatListAvatar(
                  title: item.title,
                  avatarUrl: item.avatarUrl,
                  showOnlineDot: item.isOnline,
                  isSelected: selected,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (item.timeLabel.isNotEmpty)
                            AppPillBadge(
                              label: item.timeLabel,
                              accent: selected || isUnread,
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13.5,
                                fontStyle:
                                    item.isTyping ? FontStyle.italic : FontStyle.normal,
                                fontWeight: item.isTyping || isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (item.unreadCount > 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppGradients.accentPanel,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                boxShadow: AppShadows.primaryButton,
                              ),
                              child: Text(
                                item.unreadCount > 99 ? '99+' : item.unreadCount.toString(),
                                style: const TextStyle(
                                  color: AppColors.textOnAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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
    required this.isSelected,
  });

  final String title;
  final String? avatarUrl;
  final bool showOnlineDot;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final safeUrl = (avatarUrl ?? '').trim();

    Widget inner;
    if (safeUrl.isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.accent.withAlpha(110) : AppColors.strokeSoft,
            ),
          ),
          child: Image.network(
            safeUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _AvatarFallback(title: title, size: size);
            },
          ),
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
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withAlpha(120),
                  blurRadius: 12,
                ),
              ],
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
        gradient: AppGradients.accentPanel,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.primaryButton,
      ),
      alignment: Alignment.center,
      child: Text(
        resolveTitleInitials(title),
        style: const TextStyle(
          color: AppColors.textOnAccent,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
