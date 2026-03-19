import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class CreateChatService {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> createPrivateChat({
    required int userId,
  }) async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.post(
      '/chats/',
      data: {
        'type': 'private',
        'title': null,
        'member_ids': [userId],
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

    throw Exception('Неожиданный формат ответа при создании личного чата');
  }

  Future<Map<String, dynamic>> createGroupChat({
    required String title,
    required List<int> memberIds,
  }) async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.post(
      '/chats/',
      data: {
        'type': 'group',
        'title': title,
        'member_ids': memberIds,
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

    throw Exception('Неожиданный формат ответа при создании группового чата');
  }
}