import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/platform/desktop_layout.dart';
import 'chat_detail_messages_list.dart';
import 'message_input_bar.dart';

class ChatDetailConversationView extends StatelessWidget {
  const ChatDetailConversationView({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.isGroupChat,
    required this.currentUserId,
    required this.memberNames,
    required this.memberAvatarUrls,
    required this.onRefresh,
    required this.onSwipeReply,
    required this.onMessageActions,
    required this.onOpenFullscreenImage,
    required this.onOpenFullscreenVideo,
    required this.onOpenSenderProfile,
    required this.onReactionEmojiTap,
    required this.typingLabel,
    required this.messageController,
    required this.isEditing,
    required this.replyingTo,
    required this.replyAuthorLabel,
    required this.isSending,
    required this.isSendingImage,
    required this.isSendingVideo,
    required this.isSendingDocument,
    required this.isSendingVoice,
    required this.isRecordingVoice,
    required this.onCancelEdit,
    required this.onCancelReply,
    required this.onPickAttachment,
    required this.onVideoNote,
    required this.onVoiceRecordTap,
    required this.onVoicePickFile,
    required this.onSend,
    required this.onDesktopExtras,
    required this.onDesktopDocumentsDropped,
  });

  final List<Map<String, dynamic>> messages;
  final ScrollController scrollController;
  final bool isGroupChat;
  final int? currentUserId;
  final Map<int, String> memberNames;
  final Map<int, String?> memberAvatarUrls;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic> message) onSwipeReply;
  final void Function(Map<String, dynamic> message, Offset? menuPosition)
      onMessageActions;
  final void Function(String url) onOpenFullscreenImage;
  final void Function(String url, {required bool isVideoNote})
      onOpenFullscreenVideo;
  final void Function(int userId) onOpenSenderProfile;
  final void Function(Map<String, dynamic> message, String emoji)
      onReactionEmojiTap;
  final String? typingLabel;
  final TextEditingController messageController;
  final bool isEditing;
  final Map<String, dynamic>? replyingTo;
  final String replyAuthorLabel;
  final bool isSending;
  final bool isSendingImage;
  final bool isSendingVideo;
  final bool isSendingDocument;
  final bool isSendingVoice;
  final bool isRecordingVoice;
  final VoidCallback onCancelEdit;
  final VoidCallback onCancelReply;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;
  final VoidCallback onVoiceRecordTap;
  final VoidCallback onVoicePickFile;
  final VoidCallback onSend;
  final VoidCallback onDesktopExtras;
  final void Function(DropDoneDetails detail) onDesktopDocumentsDropped;

  @override
  Widget build(BuildContext context) {
    final chatColumn = Column(
      children: [
        Expanded(
          child: ChatDetailMessagesList(
            messages: messages,
            scrollController: scrollController,
            isGroupChat: isGroupChat,
            currentUserId: currentUserId,
            memberNames: memberNames,
            memberAvatarUrls: memberAvatarUrls,
            onRefresh: onRefresh,
            onSwipeReply: onSwipeReply,
            onMessageActions: onMessageActions,
            onOpenFullscreenImage: onOpenFullscreenImage,
            onOpenFullscreenVideo: onOpenFullscreenVideo,
            onOpenSenderProfile: onOpenSenderProfile,
            onReactionEmojiTap: onReactionEmojiTap,
          ),
        ),
        if (typingLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                typingLabel!,
                style: const TextStyle(
                  color: AppColors.accentBright,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ChatDetailMessageInputBar(
          messageController: messageController,
          isEditing: isEditing,
          replyingTo: replyingTo,
          replyAuthorLabel: replyAuthorLabel,
          isSending: isSending,
          isSendingImage: isSendingImage,
          isSendingVideo: isSendingVideo,
          isSendingDocument: isSendingDocument,
          isSendingVoice: isSendingVoice,
          isRecordingVoice: isRecordingVoice,
          onCancelEdit: onCancelEdit,
          onCancelReply: onCancelReply,
          onPickAttachment: onPickAttachment,
          onVideoNote: onVideoNote,
          onVoiceRecordTap: onVoiceRecordTap,
          onVoicePickFile: onVoicePickFile,
          onSend: onSend,
          onDesktopExtras: onDesktopExtras,
        ),
      ],
    );

    if (!isDesktopMessengerLayout) {
      return chatColumn;
    }

    return DropTarget(
      onDragDone: onDesktopDocumentsDropped,
      child: chatColumn,
    );
  }
}
