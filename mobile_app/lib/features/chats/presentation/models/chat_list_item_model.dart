class ChatListItemModel {
  const ChatListItemModel({
    required this.chatId,
    required this.chatType,
    required this.title,
    required this.avatarUrl,
    required this.subtitle,
    required this.timeLabel,
    required this.unreadCount,
    required this.isOnline,
    required this.isSelected,
    required this.isTyping,
  });

  final int chatId;
  final String chatType;
  final String title;
  final String? avatarUrl;
  final String subtitle;
  final String timeLabel;
  final int unreadCount;
  final bool isOnline;
  final bool isSelected;
  final bool isTyping;
}
