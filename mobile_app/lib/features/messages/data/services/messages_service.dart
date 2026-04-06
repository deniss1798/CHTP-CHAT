import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class MessagesService {
  final Dio _dio = ApiClient.dio;

  Future<Options> _authorizedOptions() async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    return Options(
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(int chatId) async {
    final response = await _dio.get(
      '/messages/chat/$chatId',
      options: await _authorizedOptions(),
    );

    final data = response.data;

    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    throw Exception('Неожиданный формат ответа /messages/chat/{chat_id}');
  }

  Future<Map<String, dynamic>> sendMessage({
    required int chatId,
    required String text,
  }) async {
    final response = await _dio.post(
      '/messages/',
      data: {
        'chat_id': chatId,
        'text': text,
      },
      options: await _authorizedOptions(),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Неожиданный формат ответа при отправке сообщения');
  }
}