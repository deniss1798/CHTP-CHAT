import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart' show AppGradients;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../chat_detail_formatters.dart';
import '../chat_detail_message_maps.dart';
import 'chat_detail_avatar_widgets.dart';
import 'chat_detail_message_content.dart';
import 'chat_detail_reply_quote.dart';
import 'chat_message_actions_panel.dart';

class ChatDetailMessageBubble extends StatelessWidget {
  const ChatDetailMessageBubble({
    super.key,
    required this.message,
    required this.isGroupChat,
    required this.currentUserId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.senderNameForUserId,
    required this.isMine,
    required this.onOpenActions,
    required this.onOpenFullscreenImage,
    required this.onOpenFullscreenVideo,
    required this.onOpenSenderProfile,
    this.onReactionEmojiTap,
  });

  final Map<String, dynamic> message;
  final bool isGroupChat;
  final int? currentUserId;
  final String senderName;
  final String? senderAvatarUrl;
  final String Function(int? userId) senderNameForUserId;
  final bool isMine;
  /// [menuPosition] — глобальные координаты для меню у курсора (ПКМ); `null` — снизу (тап на телефоне).
  final void Function(Offset? menuPosition) onOpenActions;
  final void Function(String url) onOpenFullscreenImage;
  final void Function(String url, {required bool isVideoNote}) onOpenFullscreenVideo;
  final void Function(int userId) onOpenSenderProfile;
  final void Function(String emoji)? onReactionEmojiTap;

  List<int> _reactorUserIds(Map<String, dynamic> m) {
    final raw = m['reactor_user_ids'];
    if (raw is! List) return [];
    final out = <int>[];
    for (final x in raw) {
      final id = ChatDetailMessageMaps.intFromDynamic(x);
      if (id != null) out.add(id);
    }
    return out;
  }

  bool _isPhoneStyle(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.sizeOf(context).shortestSide < 600;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _showGroupReactionReactors(
    BuildContext context,
    String emoji,
    List<int> userIds,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  'Реакция $emoji',
                  style: AppTextStyles.title,
                ),
              ),
              for (final id in userIds)
                ListTile(
                  title: Text(
                    senderNameForUserId(id),
                    style: AppTextStyles.bodyStrong,
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        );
      },
    );
  }

  Widget _reactionChip(
    BuildContext context,
    Map<String, dynamic> m,
    bool phoneStyle,
  ) {
    final e = m['emoji']?.toString() ?? '';
    if (e.isEmpty) return const SizedBox.shrink();
    final count = m['count'];
    final countLabel = count is num
        ? count.toInt().toString()
        : (count?.toString() ?? '0');
    final userIds = _reactorUserIds(m);
    final namesLine = userIds.map(senderNameForUserId).join(', ');

    Widget tile = Material(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onReactionEmojiTap != null ? () => onReactionEmojiTap!(e) : null,
        onLongPress: isGroupChat && userIds.isNotEmpty && phoneStyle
            ? () => _showGroupReactionReactors(context, e, userIds)
            : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            '$e $countLabel',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    if (isGroupChat && userIds.isNotEmpty && !phoneStyle) {
      tile = Tooltip(
        message: namesLine,
        preferBelow: true,
        waitDuration: const Duration(milliseconds: 350),
        child: tile,
      );
    }

    return tile;
  }

  Widget _reactionStrip(BuildContext context) {
    final raw = message['reactions'];
    if (raw is! List || raw.isEmpty) {
      return const SizedBox.shrink();
    }
    final phoneStyle = _isPhoneStyle(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final r in raw)
            if (r is Map)
              _reactionChip(
                context,
                r is Map<String, dynamic>
                    ? r
                    : Map<String, dynamic>.from(r),
                phoneStyle,
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = chatDetailFormatTime(message['created_at']?.toString());
    final isUpdated = message['is_updated'] == true;
    final mediaOnly = chatDetailIsMediaOnlyMessage(message);
    final useTimeOnMediaPreview =
        chatDetailPutsTimeOverMediaPreview(message);
    final messageType = (message['message_type'] ?? 'text').toString();
    final isVideoNote = messageType == 'video_note';
    final hasReplyPreview = message['reply_to'] is Map;
    final videoNoteCircleLayout =
        mediaOnly && isVideoNote && !hasReplyPreview && !isGroupChat;

    Widget mainContent = ChatDetailMessageContent(
      message: message,
      isMine: isMine,
      onOpenFullscreenImage: onOpenFullscreenImage,
      onOpenFullscreenVideo: onOpenFullscreenVideo,
    );
    if (useTimeOnMediaPreview) {
      mainContent = ClipRRect(
        borderRadius: BorderRadius.circular(
          isVideoNote ? 999 : 12,
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            mainContent,
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(115),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUpdated)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(
                          'изм.',
                          style: TextStyle(
                            color: Colors.white.withAlpha(190),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isMine) ...[
                      Icon(
                        (message['delivery_status']?.toString() == 'read')
                            ? AppIcons.doneAll
                            : AppIcons.done,
                        size: 14,
                        color: (message['delivery_status']?.toString() == 'read')
                            ? const Color(0xFFB8E0FF)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withAlpha(235),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bubbleShape = videoNoteCircleLayout
        ? BorderRadius.circular(110)
        : BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.xl),
            topRight: const Radius.circular(AppRadius.xl),
            bottomLeft: Radius.circular(isMine ? AppRadius.xl : AppRadius.sm),
            bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.xl),
          );

    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: bubbleShape,
        splashColor: useTimeOnMediaPreview
            ? Colors.transparent
            : Colors.white.withAlpha(28),
        highlightColor: useTimeOnMediaPreview ? Colors.transparent : null,
        onTap: primaryTapOpensMessageMenu(context)
            ? () => onOpenActions(null)
            : null,
        onSecondaryTapDown: (details) =>
            onOpenActions(details.globalPosition),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: useTimeOnMediaPreview
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
          decoration: BoxDecoration(
            gradient: useTimeOnMediaPreview
                ? null
                : (isMine ? AppGradients.bubbleMine : AppGradients.bubbleOther),
            borderRadius: bubbleShape,
            border: useTimeOnMediaPreview
                ? null
                : Border.all(
                    color: isMine
                        ? AppColors.navRailActiveAccent.withValues(alpha: 0.72)
                        : AppColors.accent.withValues(alpha: 0.20),
                    width: isMine ? 1.15 : 1,
                  ),
            boxShadow: useTimeOnMediaPreview
                ? null
                : (isMine ? AppShadows.accentStroke : AppShadows.lift),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isGroupChat && !isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    senderName,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentGlow,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (ChatDetailMessageMaps.intFromDynamic(
                    message['forwarded_from_user_id'],
                  ) !=
                  null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Переслано от ${senderNameForUserId(ChatDetailMessageMaps.intFromDynamic(message['forwarded_from_user_id'])!)}',
                      textAlign: TextAlign.left,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ChatDetailReplyQuote(
                message: message,
                isMine: isMine,
                senderNameForUserId: senderNameForUserId,
              ),
              mainContent,
              if (!useTimeOnMediaPreview) const SizedBox(height: AppSpacing.xs),
              if (!useTimeOnMediaPreview)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUpdated)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Text(
                          'изменено',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isMine) ...[
                      Icon(
                        (message['delivery_status']?.toString() == 'read')
                            ? AppIcons.doneAll
                            : AppIcons.done,
                        size: 15,
                        color: (message['delivery_status']?.toString() == 'read')
                            ? const Color(0xFFB8E0FF)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      time,
                      style: AppTextStyles.caption.copyWith(
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.92)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            bubble,
            _reactionStrip(context),
          ],
        ),
      );
    }

    final senderId = ChatDetailMessageMaps.intFromDynamic(message['sender_id']);
    final avatarChild = Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: ChatDetailCircleAvatar(
        title: senderName,
        avatarUrl: senderAvatarUrl,
        size: 34,
      ),
    );
    final Widget leadingAvatar = (senderId != null && senderId != currentUserId)
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onOpenSenderProfile(senderId),
              child: avatarChild,
            ),
          )
        : avatarChild;

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          leadingAvatar,
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble,
                _reactionStrip(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
