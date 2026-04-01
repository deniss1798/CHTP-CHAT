import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

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
      final aDate =
          DateTime.tryParse(a['last_message_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          DateTime.tryParse(b['last_message_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return chats;
  }

  Map<String, dynamic> _normalizeChat(Map<String, dynamic> raw) {
    final chat = Map<String, dynamic>.from(raw);

    chat['last_message'] = raw['last_message'];
    chat['last_message_at'] = raw['last_message_at'];
    chat['last_message_sender_id'] = raw['last_message_sender_id'];
    chat['unread_count'] = raw['unread_count'] ?? 0;

    return chat;
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
}