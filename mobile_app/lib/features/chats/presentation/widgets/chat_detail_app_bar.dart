import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../core/platform/desktop_layout.dart';

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
    this.onSearchInChat,
    this.onVideoCall,
    this.onMorePrivate,
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
  final VoidCallback? onSearchInChat;
  final VoidCallback? onVideoCall;
  final VoidCallback? onMorePrivate;

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopMessengerLayout;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: AppSurface(
        tone: AppSurfaceTone.selected,
        radius: 26,
        borderColor: AppColors.accent.withValues(alpha: 0.38),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        shadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
          ...AppShadows.card,
        ],
        child: Row(
          children: [
            AppIconButtonSurface(
              icon: AppIcons.back,
              tooltip: 'Назад',
              onTap: onBack,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  avatarLeading,
                  const SizedBox(width: 10),
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
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (!isGroupChat) const SizedBox(height: 2),
                        if (!isGroupChat)
                          Row(
                            children: [
                              if (peerOnline) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(right: 6, top: 1),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2ECC71),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  peerSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: peerOnline
                                        ? const Color(0xFF2ECC71)
                                        : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isDesktop) ...[
            if (onSearchInChat != null) ...[
              AppIconButtonSurface(
                icon: AppIcons.search,
                tooltip: 'Поиск в чате',
                onTap: onSearchInChat!,
              ),
              const SizedBox(width: 4),
            ],
            if (isGroupChat) ...[
              AppIconButtonSurface(
                icon: AppIcons.call,
                tooltip: 'Групповой звонок',
                onTap: onGroupCall,
                active: true,
              ),
              const SizedBox(width: 4),
              AppIconButtonSurface(
                icon: AppIcons.photoCamera,
                tooltip: 'Изменить аватар группы',
                onTap: isUploadingChatAvatar ? null : onPickGroupAvatar,
                iconColor: isUploadingChatAvatar
                    ? AppColors.textMuted
                    : AppColors.navRailActiveAccent,
              ),
              const SizedBox(width: 4),
              AppIconButtonSurface(
                icon: AppIcons.personAdd,
                tooltip: 'Добавить участника',
                onTap: onAddMember,
              ),
              const SizedBox(width: 2),
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
            ] else ...[
              AppIconButtonSurface(
                icon: AppIcons.call,
                tooltip: 'Голосовой звонок',
                onTap: onVoiceCall,
                active: true,
              ),
              if (onVideoCall != null) ...[
                const SizedBox(width: 4),
                AppIconButtonSurface(
                  icon: AppIcons.videocam,
                  tooltip: 'Видеозвонок',
                  onTap: onVideoCall!,
                  active: true,
                ),
              ],
              if (onMorePrivate != null) ...[
                const SizedBox(width: 2),
                AppIconButtonSurface(
                  icon: AppIcons.moreVert,
                  tooltip: 'Ещё',
                  onTap: onMorePrivate!,
                ),
              ],
            ],
            ] else ...[
            if (!isGroupChat)
              AppIconButtonSurface(
                icon: AppIcons.call,
                tooltip: 'Голосовой звонок',
                onTap: onVoiceCall,
                active: true,
              ),
            if (isGroupChat) ...[
              const SizedBox(width: 8),
              AppIconButtonSurface(
                icon: AppIcons.call,
                tooltip: 'Групповой звонок',
                onTap: onGroupCall,
                active: true,
              ),
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
          ],
        ),
      ),
    );
  }
}
