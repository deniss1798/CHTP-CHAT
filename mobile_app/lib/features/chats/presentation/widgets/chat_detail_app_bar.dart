import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';

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
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withAlpha(10),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              AppIcons.back,
              color: AppColors.textPrimary,
            ),
          ),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isGroupChat) ...[
                        const SizedBox(height: 2),
                        Text(
                          peerSubtitle,
                          style: TextStyle(
                            color: peerOnline
                                ? AppColors.accentBright
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isGroupChat)
            IconButton(
              tooltip: 'Голосовой звонок',
              onPressed: onVoiceCall,
              icon: const Icon(
                AppIcons.call,
                color: AppColors.accent,
              ),
            ),
          if (isGroupChat)
            IconButton(
              tooltip: 'Групповой звонок',
              onPressed: onGroupCall,
              icon: const Icon(
                Icons.groups,
                color: AppColors.accent,
              ),
            ),
          if (isGroupChat)
            IconButton(
              tooltip: 'Изменить аватар группы',
              onPressed: isUploadingChatAvatar ? null : onPickGroupAvatar,
              icon: isUploadingChatAvatar
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      AppIcons.photoCamera,
                      color: AppColors.accent,
                    ),
            ),
          if (isGroupChat)
            IconButton(
              tooltip: 'Добавить участника',
              onPressed: onAddMember,
              icon: const Icon(
                AppIcons.personAdd,
                color: AppColors.accent,
              ),
            ),
          if (isGroupChat)
            PopupMenuButton<String>(
              tooltip: 'Меню группы',
              icon: const Icon(
                AppIcons.moreVert,
                color: AppColors.textPrimary,
              ),
              color: AppColors.surface,
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
      ),
    );
  }
}
