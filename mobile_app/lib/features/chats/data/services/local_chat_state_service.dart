import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

class LocalChatStateService {
  static const String _lastReadMapKey = 'chat_last_read_message_ids';
  static const String _currentUserIdKey = 'chat_current_user_id';
  static const String _cachedChatsKey = 'chat_cached_list_v1';
  static const String _cachedMessagesPrefix = 'chat_cached_messages_v1_';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> _readMap() async {
    final raw = await _storage.read(key: _lastReadMapKey);

    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return {};
  }

  Future<void> _writeMap(Map<String, dynamic> value) async {
    await _storage.write(
      key: _lastReadMapKey,
      value: jsonEncode(value),
    );
  }

  Future<int?> getLastReadMessageId(int chatId) async {
    final map = await _readMap();
    final value = map[chatId.toString()];

    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// Одно чтение хранилища для слияния с ответом API (список чатов).
  Future<Map<int, int>> getAllLastReadMessageIds() async {
    final map = await _readMap();
    final out = <int, int>{};
    for (final e in map.entries) {
      final id = int.tryParse(e.key);
      if (id == null) continue;
      final v = e.value;
      final mid = v is int ? v : int.tryParse(v.toString());
      if (mid != null) out[id] = mid;
    }
    return out;
  }

  Future<void> markChatAsRead({
    required int chatId,
    required int? lastMessageId,
  }) async {
    if (lastMessageId == null) return;

    final map = await _readMap();
    map[chatId.toString()] = lastMessageId;
    await _writeMap(map);
  }

  Future<void> saveCurrentUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserIdKey, userId);
  }

  Future<int?> getCachedCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentUserIdKey);
  }

  Future<void> cacheChats(List<ChatSummary> chats) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = chats.map(_chatToJson).toList(growable: false);
    await prefs.setString(_cachedChatsKey, jsonEncode(encoded));
  }

  Future<List<ChatSummary>> getCachedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedChatsKey);
    if (raw == null || raw.trim().isEmpty) return const <ChatSummary>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ChatSummary>[];
      final chats = <ChatSummary>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          chats.add(ChatSummary.fromApi(item));
        } else if (item is Map) {
          chats.add(ChatSummary.fromApi(Map<String, dynamic>.from(item)));
        }
      }
      chats.sort(compareChatSummariesListOrder);
      return chats;
    } catch (_) {
      return const <ChatSummary>[];
    }
  }

  Future<void> cacheMessages({
    required int chatId,
    required List<Map<String, dynamic>> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cachedMessagesPrefix$chatId',
      jsonEncode(messages),
    );
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(int chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cachedMessagesPrefix$chatId');
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      final messages = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          messages.add(item);
        } else if (item is Map) {
          messages.add(Map<String, dynamic>.from(item));
        }
      }
      return messages;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _chatToJson(ChatSummary chat) {
    return {
      'id': chat.id,
      'type': chat.type,
      'title': chat.title,
      'avatar_url': chat.avatarUrl,
      'created_by': chat.createdBy,
      'last_message': chat.lastMessage,
      'last_message_type': chat.lastMessageType,
      'last_message_at': chat.lastMessageAtRaw,
      'last_message_sender_id': chat.lastMessageSenderId,
      'last_message_sender_name': chat.lastMessageSenderName,
      'last_message_id': chat.lastMessageId,
      'my_last_read_message_id': chat.myLastReadMessageId,
      'unread_count': chat.unreadCount,
      'peer_last_seen_at': chat.peerLastSeenAtRaw,
      'is_archived': chat.isArchived,
      'notifications_muted': chat.notificationsMuted,
      'is_pinned': chat.isPinned,
    };
  }
}
