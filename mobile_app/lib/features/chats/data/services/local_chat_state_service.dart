import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';
import 'local_chat_database.dart';

class LocalChatStateService {
  static const String _lastReadMapKey = 'chat_last_read_message_ids';
  static const String _currentUserIdKey = 'chat_current_user_id';
  static const String _legacyCachedChatsKey = 'chat_cached_list_v1';
  static const String _legacyCachedMessagesPrefix = 'chat_cached_messages_v1_';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalChatDatabase _database = LocalChatDatabase.instance;

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
    await _storage.write(key: _lastReadMapKey, value: jsonEncode(value));
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
    await _storage.write(key: _currentUserIdKey, value: userId.toString());
  }

  Future<int?> getCachedCurrentUserId() async {
    final raw = await _storage.read(key: _currentUserIdKey);
    if (raw != null && raw.trim().isNotEmpty) {
      return int.tryParse(raw);
    }

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getInt(_currentUserIdKey);
    if (legacy != null) {
      await saveCurrentUserId(legacy);
    }
    return legacy;
  }

  Future<void> cacheChats(List<ChatSummary> chats) async {
    await _database.upsertChats(chats);
  }

  Future<List<ChatSummary>> getCachedChats() async {
    final chats = await _database.getChats();
    if (chats.isNotEmpty) return chats;

    final legacy = await _getLegacyCachedChats();
    if (legacy.isNotEmpty) {
      await _database.upsertChats(legacy);
    }
    return legacy;
  }

  Future<void> cacheMessages({
    required int chatId,
    required List<Map<String, dynamic>> messages,
  }) async {
    await _database.upsertMessages(chatId: chatId, messages: messages);
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(int chatId) async {
    final messages = await _database.getMessages(chatId);
    if (messages.isNotEmpty) return messages;

    final legacy = await _getLegacyCachedMessages(chatId);
    if (legacy.isNotEmpty) {
      await _database.upsertMessages(chatId: chatId, messages: legacy);
    }
    return legacy;
  }

  Future<void> deleteCachedMessage(int messageId) async {
    await _database.deleteMessageByServerId(messageId);
  }

  Future<List<ChatSummary>> _getLegacyCachedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyCachedChatsKey);
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

  Future<List<Map<String, dynamic>>> _getLegacyCachedMessages(
    int chatId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_legacyCachedMessagesPrefix$chatId');
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
}
