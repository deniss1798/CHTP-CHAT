import 'package:dio/dio.dart';
import '../../../../core/formatting/server_time.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/network/url_helper.dart';

class ChatsService {
  final Dio _dio = ApiClient.dio;

  Future<List<Map<String, dynamic>>> getChats({
    required int currentUserId,
  }) async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.get(
      '/chats/',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data;

    if (data is! List) {
      throw Exception('Неожиданный формат ответа /chats/');
    }

    final chats = data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(_normalizeChat)
        .toList();

    chats.sort((a, b) {
      final aMs = serverInstantMillis(a['last_message_at']?.toString()) ?? 0;
      final bMs = serverInstantMillis(b['last_message_at']?.toString()) ?? 0;
      return bMs.compareTo(aMs);
    });

    return chats;
  }

  String? _normalizeAvatarUrl(dynamic value) {
  if (value == null) return null;

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  if (raw.startsWith('/')) {
    return '${ApiClient.baseUrl}$raw';
  }

  return '${ApiClient.baseUrl}/$raw';
}

  Map<String, dynamic> _normalizeChat(Map<String, dynamic> raw) {
  final chat = Map<String, dynamic>.from(raw);

  chat['avatar_url'] = UrlHelper.absoluteMediaUrl(
    raw['avatar_url'] ?? raw['avatarUrl'],
  );
  chat['last_message'] = raw['last_message'] ?? raw['lastMessage'];
  chat['last_message_type'] =
      raw['last_message_type'] ?? raw['lastMessageType'];
  chat['last_message_at'] = raw['last_message_at'] ?? raw['lastMessageAt'];
  chat['last_message_sender_id'] =
      raw['last_message_sender_id'] ?? raw['lastMessageSenderId'];
  chat['last_message_id'] = raw['last_message_id'] ?? raw['lastMessageId'];
  chat['my_last_read_message_id'] =
      raw['my_last_read_message_id'] ?? raw['myLastReadMessageId'];
  chat['unread_count'] = _parseUnreadCount(
    raw['unread_count'] ?? raw['unreadCount'],
  );
  chat['peer_last_seen_at'] =
      raw['peer_last_seen_at'] ?? raw['peerLastSeenAt'];

  return chat;
}

  int _parseUnreadCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<Map<String, dynamic>> addMemberToChat({
    required int chatId,
    required int userId,
  }) async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.post(
      '/chats/$chatId/members',
      data: {
        'user_id': userId,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Неожиданный формат ответа при добавлении участника');
  }

  Future<void> updateGroupTitle({
    required int chatId,
    required String title,
  }) async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    await _dio.patch(
      '/chats/$chatId',
      data: {'title': title},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<void> leaveGroup({required int chatId}) async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    await _dio.post(
      '/chats/$chatId/leave',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }

  /// Имена и аватары участников (для UI группового звонка, если список не был загружен в чате).
  Future<({Map<int, String> names, Map<int, String?> avatars})>
      loadChatMembersRoster(int chatId) async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    final response = await _dio.get(
      '/chats/$chatId/members',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final names = <int, String>{};
    final avatars = <int, String?>{};
    final data = response.data;
    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final rawId = map['id'];
        int? userId;
        if (rawId is int) {
          userId = rawId;
        } else {
          userId = int.tryParse(rawId?.toString() ?? '');
        }
        if (userId == null) continue;
        final username = (map['username'] ?? '').toString().trim();
        names[userId] =
            username.isNotEmpty ? username : 'Участник $userId';
        final rawAvatar = (map['avatar_url'] ?? map['avatarUrl'] ?? '')
            .toString()
            .trim();
        avatars[userId] = UrlHelper.absoluteMediaUrl(
          rawAvatar.isNotEmpty ? rawAvatar : null,
        );
      }
    }
    return (names: names, avatars: avatars);
  }

  Future<void> removeGroupMember({
    required int chatId,
    required int memberUserId,
  }) async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    await _dio.delete(
      '/chats/$chatId/members/$memberUserId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }
}