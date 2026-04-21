import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
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

  Widget _reactionStrip() {
    final raw = message['reactions'];
    if (raw is! List || raw.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final r in raw)
            if (r is Map)
              Material(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onReactionEmojiTap != null
                      ? () {
                          final e = r['emoji']?.toString() ?? '';
                          if (e.isEmpty) return;
                          onReactionEmojiTap!(e);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '${r['emoji']} ${r['count']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
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
    if (mediaOnly) {
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
                            ? const Color(0xFF5EB8FF)
                            : Colors.white.withAlpha(210),
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
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 8),
            bottomRight: Radius.circular(isMine ? 8 : 18),
          );

    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: bubbleShape,
        splashColor: mediaOnly ? Colors.transparent : Colors.white.withAlpha(28),
        highlightColor: mediaOnly ? Colors.transparent : null,
        onTap: primaryTapOpensMessageMenu(context)
            ? () => onOpenActions(null)
            : null,
        onSecondaryTapDown: (details) =>
            onOpenActions(details.globalPosition),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: mediaOnly
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: mediaOnly
                ? null
                : (isMine ? AppGradients.bubbleMine : AppGradients.bubbleOther),
            borderRadius: bubbleShape,
            border: mediaOnly || !isMine
                ? null
                : Border.all(
                    color: AppColors.accentBorder.withAlpha(110),
                    width: 1,
                  ),
            boxShadow: mediaOnly
                ? null
                : (isMine ? AppShadows.accentStroke : AppShadows.lift),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isGroupChat && !isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    senderName,
                    style: const TextStyle(
                      color: AppColors.accentGlow,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (ChatDetailMessageMaps.intFromDynamic(
                    message['forwarded_from_user_id'],
                  ) !=
                  null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Переслано от ${senderNameForUserId(ChatDetailMessageMaps.intFromDynamic(message['forwarded_from_user_id'])!)}',
                      textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
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
              if (!mediaOnly) const SizedBox(height: 8),
              if (!mediaOnly)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUpdated)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          'изменено',
                      style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
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
                            ? AppColors.accentBright
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
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
            _reactionStrip(),
          ],
        ),
      );
    }

    final senderId = ChatDetailMessageMaps.intFromDynamic(message['sender_id']);
    final avatarChild = Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 6),
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
                _reactionStrip(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
