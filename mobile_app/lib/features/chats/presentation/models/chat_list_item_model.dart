class ChatListItemModel {
  const ChatListItemModel({
    required this.chatId,
    required this.chatType,
    required this.title,
    required this.avatarUrl,
    this.lastMessageType,
    required this.subtitle,
    this.subtitleGroupAuthor,
    this.subtitleGroupMessageBody,
    required this.timeLabel,
    required this.unreadCount,
    required this.isOnline,
    required this.isSelected,
    required this.isTyping,
    required this.isArchived,
    required this.notificationsMuted,
    required this.isPinned,
  });

  final int chatId;
  final String chatType;
  final String title;
  final String? avatarUrl;
  final String? lastMessageType;
  final String subtitle;
  final String? subtitleGroupAuthor;
  final String? subtitleGroupMessageBody;
  final String timeLabel;
  final int unreadCount;
  final bool isOnline;
  final bool isSelected;
  final bool isTyping;

  /// Локально для действий строки ([PATCH /chats/:id/member-preferences]).
  final bool isArchived;
  final bool notificationsMuted;
  final bool isPinned;
}
