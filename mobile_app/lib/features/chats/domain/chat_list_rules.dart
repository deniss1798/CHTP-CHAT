import '../../../core/formatting/server_time.dart';

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
}) {
  final text = lastMessage?.trim();
  if (text != null && text.isNotEmpty) {
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
  final sameDay = now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;

  if (sameDay) {
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
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
