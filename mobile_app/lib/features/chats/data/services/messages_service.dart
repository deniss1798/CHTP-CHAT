import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

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

  Future<void> markChatRead({
    required int chatId,
    required int messageId,
  }) async {
    final base = await _authorizedOptions();
    await _dio.post(
      '/chats/$chatId/read',
      data: {'message_id': messageId},
      options: base.copyWith(
        validateStatus: (s) =>
            s != null && (s == 200 || s == 201 || s == 204 || s == 404),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getChatReadState(int chatId) async {
    final base = await _authorizedOptions();
    final response = await _dio.get(
      '/chats/$chatId/read-state',
      options: base.copyWith(
        validateStatus: (s) =>
            s != null && ((s >= 200 && s < 300) || s == 404),
      ),
    );
    if (response.statusCode == 404) {
      return [];
    }
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
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
    int? replyToMessageId,
  }) async {
    final response = await _dio.post(
      '/messages/',
      data: {
        'chat_id': chatId,
        'text': text,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
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

  Future<Map<String, dynamic>> forwardMessage({
    required int targetChatId,
    required int sourceMessageId,
  }) async {
    final response = await _dio.post(
      '/messages/forward',
      data: {
        'target_chat_id': targetChatId,
        'source_message_id': sourceMessageId,
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

    throw Exception('Неожиданный формат ответа при пересылке');
  }

  Future<Map<String, dynamic>> updateMessage({
    required int messageId,
    required String text,
  }) async {
    final response = await _dio.patch(
      '/messages/$messageId',
      data: {'text': text},
      options: await _authorizedOptions(),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Неожиданный формат ответа при редактировании сообщения');
  }

  Future<void> deleteMessage(int messageId) async {
    await _dio.delete(
      '/messages/$messageId',
      options: await _authorizedOptions(),
    );
  }

  Future<Map<String, dynamic>> sendPhotoMessage({
    required int chatId,
    required String imagePath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    final mimeType = lookupMimeType(imagePath) ?? lookupMimeType(fileName) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final formData = FormData.fromMap({
      'chat_id': chatId.toString(),
      if (replyToMessageId != null)
        'reply_to_message_id': replyToMessageId.toString(),
      'file': await MultipartFile.fromFile(
        imagePath,
        filename: fileName,
        contentType: mimeParts.length == 2
            ? MediaType(mimeParts[0], mimeParts[1])
            : MediaType('application', 'octet-stream'),
      ),
    });

    final response = await _dio.post(
      '/messages/photo',
      data: formData,
      options: (await _authorizedOptions()).copyWith(
        contentType: 'multipart/form-data',
      ),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Неожиданный формат ответа при отправке фото');
  }

  Future<Map<String, dynamic>> sendVideoMessage({
    required int chatId,
    required String videoPath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    final mimeType =
        lookupMimeType(videoPath) ?? lookupMimeType(fileName) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final formData = FormData.fromMap({
      'chat_id': chatId.toString(),
      if (replyToMessageId != null)
        'reply_to_message_id': replyToMessageId.toString(),
      'file': await MultipartFile.fromFile(
        videoPath,
        filename: fileName,
        contentType: mimeParts.length == 2
            ? MediaType(mimeParts[0], mimeParts[1])
            : MediaType('application', 'octet-stream'),
      ),
    });

    final response = await _dio.post(
      '/messages/video',
      data: formData,
      options: (await _authorizedOptions()).copyWith(
        contentType: 'multipart/form-data',
      ),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Неожиданный формат ответа при отправке видео');
  }

  Future<Map<String, dynamic>> sendVideoNoteMessage({
    required int chatId,
    required String videoPath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    final mimeType =
        lookupMimeType(videoPath) ?? lookupMimeType(fileName) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final formData = FormData.fromMap({
      'chat_id': chatId.toString(),
      if (replyToMessageId != null)
        'reply_to_message_id': replyToMessageId.toString(),
      'file': await MultipartFile.fromFile(
        videoPath,
        filename: fileName,
        contentType: mimeParts.length == 2
            ? MediaType(mimeParts[0], mimeParts[1])
            : MediaType('application', 'octet-stream'),
      ),
    });

    final response = await _dio.post(
      '/messages/video_note',
      data: formData,
      options: (await _authorizedOptions()).copyWith(
        contentType: 'multipart/form-data',
      ),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Неожиданный формат ответа при отправке видеосообщения');
  }

  Future<Map<String, dynamic>> sendDocumentMessage({
    required int chatId,
    required String filePath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    final mimeType =
        lookupMimeType(filePath) ?? lookupMimeType(fileName) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final formData = FormData.fromMap({
      'chat_id': chatId.toString(),
      if (replyToMessageId != null)
        'reply_to_message_id': replyToMessageId.toString(),
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: mimeParts.length == 2
            ? MediaType(mimeParts[0], mimeParts[1])
            : MediaType('application', 'octet-stream'),
      ),
    });

    final response = await _dio.post(
      '/messages/document',
      data: formData,
      options: (await _authorizedOptions()).copyWith(
        contentType: 'multipart/form-data',
      ),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Неожиданный формат ответа при отправке файла');
  }
}
