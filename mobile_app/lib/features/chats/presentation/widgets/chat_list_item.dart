import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../domain/chat_list_rules.dart';
import '../models/chat_list_item_model.dart';

IconData? _listPreviewIcon(ChatListItemModel item) {
  if (item.isTyping) return null;
  final sub = item.subtitle.toLowerCase();
  // «Вызов отменён» и т.п. — без отдельной иконки, только строка (избегаем «двух трубок»).
  if (sub.contains('отмен') ||
      sub.contains('пропущ') ||
      sub.contains('вызов отмен')) {
    return null;
  }
  if (item.chatType == 'group' && item.subtitleGroupAuthor != null) {
    return null;
  }
  if (item.chatType == 'group') {
    return Icons.group_outlined;
  }
  final t = (item.lastMessageType ?? '').trim().toLowerCase();
  switch (t) {
    case 'voice':
      return Icons.mic_none_rounded;
    case 'video':
    case 'video_note':
      return Icons.videocam_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'document':
    case 'file':
      return Icons.insert_drive_file_outlined;
    default:
      return null;
  }
}

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
    final previewIcon = _listPreviewIcon(item);
    final isUnread = item.unreadCount > 0;
    final selected = item.isSelected;
    final subtitleColor = item.isTyping
        ? AppColors.accentBright
        : (isUnread ? AppColors.textPrimary : AppColors.textSecondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: selected
                ? AppGradients.selectedPanel
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF171717),
                      Color(0xFF111111),
                      Color(0xFF19110D),
                    ],
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppColors.accentBright
                  : AppColors.strokeSoft,
              width: selected ? 1.1 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      blurRadius: 18,
                      spreadRadius: -6,
                      offset: const Offset(0, 10),
                    ),
                    ...AppShadows.lift,
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                                fontSize: 17,
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (item.timeLabel.isNotEmpty)
                            Text(
                              item.timeLabel,
                              style: TextStyle(
                                color: selected || isUnread
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          if (previewIcon != null) ...[
                            Icon(
                              previewIcon,
                              size: 17,
                              color: isUnread
                                  ? AppColors.textSecondary
                                  : AppColors.navRailInactive,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: item.subtitleGroupAuthor != null &&
                                    item.subtitleGroupMessageBody != null
                                ? Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                    fontSize: 14,
                                        height: 1.25,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              '${item.subtitleGroupAuthor}: ',
                                          style: TextStyle(
                                            color: item.isTyping
                                                ? AppColors.accentBright
                                                : AppColors.textPrimary,
                                            fontStyle: item.isTyping
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        TextSpan(
                                          text: item.subtitleGroupMessageBody!,
                                          style: TextStyle(
                                            color: item.isTyping
                                                ? AppColors.accentBright
                                                : AppColors.textSecondary,
                                            fontStyle: item.isTyping
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 14,
                                      fontStyle: item.isTyping
                                          ? FontStyle.italic
                                          : FontStyle.normal,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.navRailActiveAccent,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                boxShadow: AppShadows.accentStroke,
                              ),
                              child: Text(
                                item.unreadCount > 99 ? '99+' : item.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
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
    const size = 58.0;
    final safeUrl = (avatarUrl ?? '').trim();

    Widget inner;
    if (safeUrl.isNotEmpty) {
      inner = ClipOval(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? AppColors.navRailActiveAccent.withAlpha(190)
                  : AppColors.strokeSoft,
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
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withAlpha(100),
                  blurRadius: 8,
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
        shape: BoxShape.circle,
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
