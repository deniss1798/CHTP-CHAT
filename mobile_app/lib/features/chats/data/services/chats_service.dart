import 'package:dio/dio.dart';

import '../../../../core/formatting/server_time.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/chat_models.dart';

class ChatsService {
  final Dio _dio = ApiClient.dio;

  Future<List<ChatSummary>> getChats({
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
        .map(ChatSummary.fromApi)
        .toList();

    chats.sort((a, b) {
      final aMs = serverInstantMillis(a.lastMessageAtRaw) ?? 0;
      final bMs = serverInstantMillis(b.lastMessageAtRaw) ?? 0;
      return bMs.compareTo(aMs);
    });

    return chats;
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
