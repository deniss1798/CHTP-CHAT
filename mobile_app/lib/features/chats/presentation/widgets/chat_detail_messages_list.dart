import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../app/theme/app_colors.dart';
import '../chat_detail_formatters.dart';
import 'chat_detail_date_divider.dart';
import 'chat_detail_message_bubble.dart';

class ChatDetailMessagesList extends StatelessWidget {
  const ChatDetailMessagesList({
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
  final void Function(String url, {required bool isVideoNote}) onOpenFullscreenVideo;
  final void Function(int userId) onOpenSenderProfile;
  final void Function(Map<String, dynamic> message, String emoji) onReactionEmojiTap;

  bool _isMine(Map<String, dynamic> message) {
    final senderId = message['sender_id'];
    if (currentUserId == null || senderId == null) return false;
    if (senderId is int) return senderId == currentUserId;
    return int.tryParse(senderId.toString()) == currentUserId;
  }

  String _senderName(Map<String, dynamic> message) {
    final rawSenderId = message['sender_id'];
    int? senderId;
    if (rawSenderId is int) {
      senderId = rawSenderId;
    } else {
      senderId = int.tryParse(rawSenderId.toString());
    }
    if (senderId == null) return 'Пользователь';
    if (senderId == currentUserId) return 'Вы';
    return memberNames[senderId] ?? 'Пользователь';
  }

  String? _senderAvatarUrl(Map<String, dynamic> message) {
    final rawSenderId = message['sender_id'];
    int? senderId;
    if (rawSenderId is int) {
      senderId = rawSenderId;
    } else {
      senderId = int.tryParse(rawSenderId.toString());
    }
    if (senderId == null) return null;
    return memberAvatarUrls[senderId];
  }

  String _senderNameForUserId(int? userId) {
    if (userId == null) return 'Пользователь';
    if (userId == currentUserId) return 'Вы';
    return memberNames[userId] ?? 'Пользователь';
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'Сообщений пока нет',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final children = <Widget>[];

          if (chatDetailShouldShowDateDivider(messages, index)) {
            final label =
                chatDetailFormatDateLabel(message['created_at']?.toString());
            if (label.isNotEmpty) {
              children.add(ChatDetailDateDivider(label: label));
            }
          }

          children.add(
            Slidable(
              key: ValueKey('slidable-${message['id']}'),
              startActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.22,
                children: [
                  SlidableAction(
                    onPressed: (_) => onSwipeReply(message),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    icon: Icons.reply,
                    label: 'Ответ',
                  ),
                ],
              ),
              child: ChatDetailMessageBubble(
                message: message,
                isGroupChat: isGroupChat,
                currentUserId: currentUserId,
                senderName: _senderName(message),
                senderAvatarUrl: _senderAvatarUrl(message),
                senderNameForUserId: _senderNameForUserId,
                isMine: _isMine(message),
                onOpenActions: (pos) => onMessageActions(message, pos),
                onOpenFullscreenImage: onOpenFullscreenImage,
                onOpenFullscreenVideo: onOpenFullscreenVideo,
                onOpenSenderProfile: onOpenSenderProfile,
                onReactionEmojiTap: (emoji) => onReactionEmojiTap(message, emoji),
              ),
            ),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          );
        },
      ),
    );
  }
}
