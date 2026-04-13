import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class MessagesService {
  final Dio _dio = ApiClient.dio;

  String _trimRightSlash(String s) {
    var t = s.trim();
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  /// Multipart через отдельный [ApiClient.multipartDio] и полный URL.
  /// При 405 — один повтор с «другой» базой: без последнего сегмента `api` или с суффиксом `/api`.
  String _alternateOriginFor405(String root) {
    final r = _trimRightSlash(root);
    final uri = Uri.parse(r);
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isNotEmpty && segs.last == 'api') {
      final parent = uri.replace(
        pathSegments: segs.sublist(0, segs.length - 1),
      );
      return _trimRightSlash(parent.toString());
    }
    return '$r/api';
  }

  Future<Response> _postMultipartForm(
    String path,
    Future<FormData> Function() buildForm,
  ) async {
    final opts = await _authorizedOptions();
    final root = _trimRightSlash(ApiClient.baseUrl);
    var rel = path;
    if (!rel.startsWith('/')) {
      rel = '/$rel';
    }

    Future<Response> sendTo(String origin) async {
      final fd = await buildForm();
      final uri = Uri.parse('$origin$rel');
      return ApiClient.multipartDio.postUri(uri, data: fd, options: opts);
    }

    try {
      return await sendTo(root);
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) {
        final alt = _alternateOriginFor405(root);
        if (alt != root) {
          return await sendTo(alt);
        }
      }
      rethrow;
    }
  }

  Map<String, dynamic> _responseMap(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Неожиданный формат ответа');
  }

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

    final response = await _postMultipartForm(
      '/messages/photo',
      () async => FormData.fromMap({
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
      }),
    );

    try {
      return _responseMap(response);
    } catch (_) {
      throw Exception('Неожиданный формат ответа при отправке фото');
    }
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

    final response = await _postMultipartForm(
      '/messages/video',
      () async => FormData.fromMap({
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
      }),
    );

    try {
      return _responseMap(response);
    } catch (_) {
      throw Exception('Неожиданный формат ответа при отправке видео');
    }
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

    final response = await _postMultipartForm(
      '/messages/video_note',
      () async => FormData.fromMap({
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
      }),
    );

    try {
      return _responseMap(response);
    } catch (_) {
      throw Exception('Неожиданный формат ответа при отправке видеосообщения');
    }
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

    final response = await _postMultipartForm(
      '/messages/file',
      () async => FormData.fromMap({
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
      }),
    );

    try {
      return _responseMap(response);
    } catch (_) {
      throw Exception('Неожиданный формат ответа при отправке файла');
    }
  }
}
