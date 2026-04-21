import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/widgets/app_surface.dart';

/// Шапка экрана чата (назад, аватар, заголовок, звонки, меню группы).
class ChatDetailAppBar extends StatelessWidget {
  const ChatDetailAppBar({
    super.key,
    required this.visibleTitle,
    required this.isGroupChat,
    required this.peerOnline,
    required this.peerSubtitle,
    required this.onBack,
    required this.avatarLeading,
    required this.onVoiceCall,
    required this.onGroupCall,
    required this.onPickGroupAvatar,
    required this.isUploadingChatAvatar,
    required this.onAddMember,
    required this.onMenuSelected,
    required this.menuShowMembersItem,
  });

  final String visibleTitle;
  final bool isGroupChat;
  final bool peerOnline;
  final String peerSubtitle;
  final VoidCallback onBack;
  /// Аватар + жест открытия профиля в личном чате собирает экран.
  final Widget avatarLeading;
  final VoidCallback onVoiceCall;
  final VoidCallback onGroupCall;
  final VoidCallback onPickGroupAvatar;
  final bool isUploadingChatAvatar;
  final VoidCallback onAddMember;
  final void Function(String value) onMenuSelected;
  final bool menuShowMembersItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.background.withAlpha(220),
        border: const Border(
          bottom: BorderSide(color: AppColors.strokeSoft),
        ),
      ),
      child: Row(
        children: [
          AppIconButtonSurface(
            icon: AppIcons.back,
            tooltip: 'Назад',
            onTap: onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                avatarLeading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        visibleTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (!isGroupChat)
                        Text(
                          peerSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: peerOnline
                                ? AppColors.accentBright
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isGroupChat)
            AppIconButtonSurface(
              icon: AppIcons.call,
              tooltip: 'Голосовой звонок',
              onTap: onVoiceCall,
              active: true,
            ),
          if (isGroupChat)
            AppIconButtonSurface(
              icon: Icons.groups_rounded,
              tooltip: 'Групповой звонок',
              onTap: onGroupCall,
              active: true,
            ),
          if (isGroupChat) ...[
            const SizedBox(width: 8),
            AppIconButtonSurface(
              icon: AppIcons.photoCamera,
              tooltip: 'Изменить аватар группы',
              onTap: isUploadingChatAvatar ? null : onPickGroupAvatar,
              iconColor: isUploadingChatAvatar
                  ? AppColors.textMuted
                  : AppColors.accentBright,
            ),
            const SizedBox(width: 8),
            AppIconButtonSurface(
              icon: AppIcons.personAdd,
              tooltip: 'Добавить участника',
              onTap: onAddMember,
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Меню группы',
              color: AppColors.surfaceRaised,
              icon: const Icon(
                AppIcons.moreVert,
                color: AppColors.textPrimary,
              ),
              onSelected: onMenuSelected,
              itemBuilder: (context) {
                return [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Переименовать группу'),
                  ),
                  if (menuShowMembersItem)
                    const PopupMenuItem(
                      value: 'members',
                      child: Text('Участники'),
                    ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text('Покинуть группу'),
                  ),
                ];
              },
            ),
          ],
        ],
      ),
    );
  }
}
