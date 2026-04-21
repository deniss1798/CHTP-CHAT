import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class MessageListPageResult {
  const MessageListPageResult({
    required this.messages,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> messages;
  final bool hasMore;
}

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

  Future<MessageListPageResult> getMessagesPage(
    int chatId, {
    int? beforeMessageId,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/messages/chat/$chatId',
      queryParameters: {
        'limit': limit,
        if (beforeMessageId != null) 'before_message_id': beforeMessageId,
      },
      options: await _authorizedOptions(),
    );

    final data = response.data;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final raw = map['messages'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(e);
          } else if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      final hasMore = map['has_more'] == true;
      return MessageListPageResult(messages: list, hasMore: hasMore);
    }

    if (data is List) {
      final list = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return MessageListPageResult(messages: list, hasMore: false);
    }

    throw Exception('Неожиданный формат ответа /messages/chat/{chat_id}');
  }

  Future<List<Map<String, dynamic>>> getMessages(int chatId) async {
    final page = await getMessagesPage(chatId, limit: 50);
    return page.messages;
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
