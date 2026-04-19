import '../../../../core/network/url_helper.dart';

/// Нормализация payload сообщений чата (REST + WebSocket) без привязки к UI.
class ChatDetailMessageMaps {
  ChatDetailMessageMaps._();

  static int? intFromDynamic(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static Map<String, dynamic>? extractMessagePayload(Map<String, dynamic> raw) {
    if (raw.containsKey('chat_id') &&
        raw.containsKey('sender_id') &&
        raw.containsKey('text')) {
      return Map<String, dynamic>.from(raw);
    }

    final message = raw['message'];
    if (message is Map<String, dynamic>) return message;
    if (message is Map) return Map<String, dynamic>.from(message);

    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    return null;
  }

  static Map<String, dynamic> normalizeMessageMap(Map<String, dynamic> raw) {
    Map<String, dynamic>? replyTo;
    final rt = raw['reply_to'];
    if (rt is Map<String, dynamic>) {
      replyTo = rt;
    } else if (rt is Map) {
      replyTo = Map<String, dynamic>.from(rt);
    }

    int? replyToId;
    final rawReplyId = raw['reply_to_message_id'];
    if (rawReplyId is int) {
      replyToId = rawReplyId;
    } else if (rawReplyId != null) {
      replyToId = int.tryParse(rawReplyId.toString());
    }

    return {
      'id': raw['id'],
      'chat_id': raw['chat_id'],
      'sender_id': raw['sender_id'],
      'text': (raw['text'] ?? '').toString(),
      'message_type': (raw['message_type'] ?? 'text').toString(),
      'media_key': raw['media_key']?.toString(),
      'media_url': UrlHelper.absoluteMediaUrl(raw['media_url']) ??
          raw['media_url']?.toString(),
      'media_mime_type': raw['media_mime_type']?.toString(),
      'media_size': raw['media_size'],
      'created_at': raw['created_at'],
      'updated_at': raw['updated_at'],
      'is_updated': raw['is_updated'] == true,
      'reply_to_message_id': replyToId,
      'reply_to': replyTo,
      'forwarded_from_user_id': intFromDynamic(raw['forwarded_from_user_id']),
      'delivery_status': raw['delivery_status']?.toString(),
    };
  }
}
