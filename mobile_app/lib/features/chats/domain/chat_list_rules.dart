import '../../../core/formatting/server_time.dart';

/// Строка подписи в списке + опциональное разбиение «автор: текст» для групп.
class ChatListSubtitleParts {
  const ChatListSubtitleParts({
    required this.line,
    this.groupAuthor,
    this.groupMessageBody,
  });

  final String line;
  final String? groupAuthor;
  final String? groupMessageBody;
}

ChatListSubtitleParts buildChatListSubtitleParts({
  String? typingLabel,
  required String chatType,
  String? lastMessage,
  String? lastMessageType,
  String? lastMessageSenderName,
  int? lastMessageSenderId,
  int? currentUserId,
}) {
  if (typingLabel != null) {
    return ChatListSubtitleParts(line: typingLabel);
  }
  final text = lastMessage?.trim();
  if (text != null && text.isNotEmpty) {
    final name = lastMessageSenderName?.trim() ?? '';
    if (chatType == 'group' && name.isNotEmpty) {
      final isMe = currentUserId != null && lastMessageSenderId == currentUserId;
      final who = isMe ? 'Вы' : name;
      return ChatListSubtitleParts(
        line: '$who: $text',
        groupAuthor: who,
        groupMessageBody: text,
      );
    }
  }
  final line = resolveChatListSubtitle(
    chatType: chatType,
    lastMessage: lastMessage,
    lastMessageType: lastMessageType,
    lastMessageSenderName: lastMessageSenderName,
    lastMessageSenderId: lastMessageSenderId,
    currentUserId: currentUserId,
  );
  return ChatListSubtitleParts(line: line);
}

String resolveChatListTitle({
  required String title,
  required int chatId,
}) {
  final normalized = title.trim();
  return normalized.isNotEmpty ? normalized : 'Чат $chatId';
}

String? previewForLastMessageType(String rawType) {
  final normalized = rawType.trim().toLowerCase();
  switch (normalized) {
    case 'image':
      return 'Фото';
    case 'video':
      return 'Видео';
    case 'video_note':
      return 'Видеосообщение';
    case 'voice':
      return 'Голосовое';
    case 'audio':
      return 'Аудио';
    case 'document':
    case 'file':
      return 'Файл';
    case 'sticker':
      return 'Стикер';
    case 'text':
      return null;
    default:
      return 'Медиа';
  }
}

String resolveChatListSubtitle({
  required String chatType,
  String? lastMessage,
  String? lastMessageType,
  String? lastMessageSenderName,
  int? lastMessageSenderId,
  int? currentUserId,
}) {
  final text = lastMessage?.trim();
  if (text != null && text.isNotEmpty) {
    if (chatType == 'group') {
      final name = lastMessageSenderName?.trim() ?? '';
      if (name.isNotEmpty) {
        final isMe = currentUserId != null && lastMessageSenderId == currentUserId;
        final who = isMe ? 'Вы' : name;
        return '$who: $text';
      }
    }
    return text;
  }

  final messageType = lastMessageType?.trim();
  if (messageType != null && messageType.isNotEmpty) {
    final preview = previewForLastMessageType(messageType);
    if (preview != null) {
      return preview;
    }
  }

  return chatType == 'private' ? 'Личный чат' : 'Групповой чат';
}

String resolveChatTimeLabel(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) return '';

  final local = parseServerUtcInstant(normalized)?.toLocal();
  if (local == null) return normalized;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final localDay = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(localDay).inDays;

  if (diffDays == 0) {
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
  if (diffDays == 1) {
    return 'Вчера';
  }

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month';
}

int resolveUnreadCount({
  required int serverUnreadCount,
  required int? currentUserId,
  required int? lastMessageId,
  required int? lastMessageSenderId,
  required int myLastReadMessageId,
}) {
  if (serverUnreadCount > 0) return serverUnreadCount;
  if (currentUserId == null) return 0;
  if (lastMessageId == null || lastMessageSenderId == null) return 0;
  if (lastMessageSenderId == currentUserId) return 0;
  return lastMessageId > myLastReadMessageId ? 1 : 0;
}

bool resolvePeerOnlineFromLastSeen(
  String? raw, {
  Duration threshold = const Duration(seconds: 180),
}) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) return false;

  final instant = parseServerUtcInstant(normalized);
  if (instant == null) return false;

  return DateTime.now().toUtc().difference(instant) <= threshold;
}

String resolveTitleInitials(String title) {
  final parts =
      title.split(' ').where((part) => part.trim().isNotEmpty).take(2).toList();

  if (parts.isEmpty) return 'Ч';
  if (parts.length == 1) {
    final word = parts.first.trim();
    return word.isNotEmpty ? word[0].toUpperCase() : 'Ч';
  }

  final first = parts[0].trim();
  final second = parts[1].trim();
  final firstChar = first.isNotEmpty ? first[0].toUpperCase() : '';
  final secondChar = second.isNotEmpty ? second[0].toUpperCase() : '';
  final result = '$firstChar$secondChar'.trim();
  return result.isNotEmpty ? result : 'Ч';
}
