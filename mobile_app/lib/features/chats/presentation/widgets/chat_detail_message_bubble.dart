import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../chat_detail_formatters.dart';
import '../chat_detail_message_maps.dart';
import 'chat_detail_avatar_widgets.dart';
import 'chat_detail_message_content.dart';
import 'chat_detail_reply_quote.dart';

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
    required this.onLongPress,
    required this.onOpenFullscreenImage,
    required this.onOpenFullscreenVideo,
    required this.onOpenSenderProfile,
  });

  final Map<String, dynamic> message;
  final bool isGroupChat;
  final int? currentUserId;
  final String senderName;
  final String? senderAvatarUrl;
  final String Function(int? userId) senderNameForUserId;
  final bool isMine;
  final VoidCallback onLongPress;
  final void Function(String url) onOpenFullscreenImage;
  final void Function(String url, {required bool isVideoNote}) onOpenFullscreenVideo;
  final void Function(int userId) onOpenSenderProfile;

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
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUpdated)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          'изм.',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
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
                        color: Color(0xFFE8EAED),
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
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          );

    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: bubbleShape,
        splashColor: mediaOnly ? Colors.transparent : Colors.white.withAlpha(28),
        highlightColor: mediaOnly ? Colors.transparent : null,
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: mediaOnly
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: mediaOnly
                ? Colors.transparent
                : (isMine ? AppColors.bubbleMine : AppColors.bubbleOther),
            borderRadius: bubbleShape,
            border: mediaOnly || !isMine
                ? null
                : Border.all(
                    color: AppColors.accentBorder.withAlpha(100),
                    width: 1,
                  ),
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
                      color: AppColors.accentBright,
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
                        color: AppColors.textMuted,
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
                            color: AppColors.textMuted,
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
                        color: AppColors.textMuted,
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
        child: bubble,
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
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
