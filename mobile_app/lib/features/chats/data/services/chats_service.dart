import 'package:dio/dio.dart';

import '../../../../core/formatting/server_time.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/chat_models.dart';

class ChatsService {
  final Dio _dio = ApiClient.dio;

  Future<ChatListPageResult> getChatsPage({
    required int currentUserId,
    int limit = 50,
    String? cursor,
    bool archived = false,
  }) async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.get(
      '/chats/',
      queryParameters: {
        'limit': limit,
        if (archived) 'archived': true,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return _chatListPageFromMap(data);
    }
    if (data is Map) {
      return _chatListPageFromMap(Map<String, dynamic>.from(data));
    }

    if (data is List) {
      final chats = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(ChatSummary.fromApi)
          .toList();
      chats.sort((a, b) {
        final aMs = serverInstantMillis(a.lastMessageAtRaw) ?? 0;
        final bMs = serverInstantMillis(b.lastMessageAtRaw) ?? 0;
        return bMs.compareTo(aMs);
      });
      return ChatListPageResult(
        chats: chats,
        hasMore: false,
        nextCursor: null,
      );
    }

    throw Exception('Неожиданный формат ответа /chats/');
  }

  Future<ChatSummary> patchChatMemberPreferences({
    required int chatId,
    bool? isArchived,
    bool? notificationsMuted,
  }) async {
    if (isArchived == null && notificationsMuted == null) {
      throw ArgumentError('Нет полей для обновления');
    }
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    final response = await _dio.patch(
      '/chats/$chatId/member-preferences',
      data: {
        if (isArchived != null) 'is_archived': isArchived,
        if (notificationsMuted != null) 'notifications_muted': notificationsMuted,
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return ChatSummary.fromApi(data);
    }
    if (data is Map) {
      return ChatSummary.fromApi(Map<String, dynamic>.from(data));
    }
    throw Exception('Неожиданный ответ PATCH member-preferences');
  }

  ChatListPageResult _chatListPageFromMap(Map<String, dynamic> data) {
    final raw = data['chats'];
    final chats = <ChatSummary>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          chats.add(ChatSummary.fromApi(item));
        } else if (item is Map) {
          chats.add(ChatSummary.fromApi(Map<String, dynamic>.from(item)));
        }
      }
    }
    chats.sort((a, b) {
      final aMs = serverInstantMillis(a.lastMessageAtRaw) ?? 0;
      final bMs = serverInstantMillis(b.lastMessageAtRaw) ?? 0;
      return bMs.compareTo(aMs);
    });
    final next = data['next_cursor']?.toString();
    final hasMore = data['has_more'] == true;
    return ChatListPageResult(
      chats: chats,
      hasMore: hasMore,
      nextCursor: (next != null && next.isNotEmpty) ? next : null,
    );
  }

  Future<List<ChatSummary>> getChats({
    required int currentUserId,
  }) async {
    final out = <ChatSummary>[];
    String? cursor;
    do {
      final page = await getChatsPage(
        currentUserId: currentUserId,
        limit: 100,
        cursor: cursor,
      );
      out.addAll(page.chats);
      cursor = page.hasMore ? page.nextCursor : null;
    } while (cursor != null);

    out.sort((a, b) {
      final aMs = serverInstantMillis(a.lastMessageAtRaw) ?? 0;
      final bMs = serverInstantMillis(b.lastMessageAtRaw) ?? 0;
      return bMs.compareTo(aMs);
    });

    return out;
  }

  Future<ChatDetail> fetchChatDetail(int chatId) async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    final response = await _dio.get(
      '/chats/$chatId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return ChatDetail.fromApi(data);
    if (data is Map) return ChatDetail.fromApi(Map<String, dynamic>.from(data));
    throw Exception('Неожиданный формат ответа /chats/{id}');
  }

  Future<List<ChatMember>> fetchChatMembers(int chatId) async {
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
    final data = response.data;
    if (data is! List) {
      throw Exception('Неожиданный формат ответа /chats/{id}/members');
    }
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(ChatMember.fromApi)
        .toList();
  }

  Future<ChatMember> addMemberToChat({
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
      return ChatMember.fromApi(data);
    }

    if (data is Map) {
      return ChatMember.fromApi(Map<String, dynamic>.from(data));
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

  Future<({Map<int, String> names, Map<int, String?> avatars})>
      loadChatMembersRoster(int chatId) async {
    final names = <int, String>{};
    final avatars = <int, String?>{};
    final members = await fetchChatMembers(chatId);

    for (final member in members) {
      names[member.id] = member.username;
      avatars[member.id] = member.avatarUrl;
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
