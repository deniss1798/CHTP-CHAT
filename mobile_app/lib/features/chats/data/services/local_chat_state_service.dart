import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalChatStateService {
  static const String _lastReadMapKey = 'chat_last_read_message_ids';
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

  Future<void> markChatAsRead({
    required int chatId,
    required int? lastMessageId,
  }) async {
    if (lastMessageId == null) return;

    final map = await _readMap();
    map[chatId.toString()] = lastMessageId;
    await _writeMap(map);
  }
}