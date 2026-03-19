class ChatPreviewModel {
  final String id;
  final String title;
  final String lastMessage;
  final String timeLabel;
  final int unreadCount;
  final bool isOnline;
  final String initials;
  final int avatarColorIndex;

  const ChatPreviewModel({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.timeLabel,
    required this.unreadCount,
    required this.isOnline,
    required this.initials,
    required this.avatarColorIndex,
  });
}