import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class StoriesService {
  final Dio _dio = ApiClient.dio;

  String _trimRightSlash(String s) {
    var t = s.trim();
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  /// Как в [MessagesService]: при 405 пробуем базу без суффикса `/api` или с `/api`.
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

  Future<Map<String, dynamic>> _authHeaders() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> getFeed() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stories/feed',
      options: Options(headers: await _authHeaders()),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Пустой ответ сторис');
    }
    return data;
  }

  Future<Map<String, dynamic>> getUserStories({required int authorId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stories/user/$authorId',
      options: Options(headers: await _authHeaders()),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Пустой ответ сторис');
    }
    return data;
  }

  Future<void> markViewed(int storyId) async {
    await _dio.post<void>(
      '/stories/$storyId/view',
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<Map<String, dynamic>> uploadStory({
    required List<int> bytes,
    required String filename,
    required String mediaType,
    String? caption,
  }) async {
    Future<FormData> buildForm() async {
      return FormData.fromMap({
        'media_type': mediaType,
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
    }

    final opts = Options(
      headers: await _authHeaders(),
      sendTimeout: const Duration(minutes: 5),
    );
    final root = _trimRightSlash(ApiClient.baseUrl);
    const rel = '/stories/upload';

    Future<Response<Map<String, dynamic>>> postUpload(String origin) async {
      final fd = await buildForm();
      final uri = Uri.parse('$origin$rel');
      return ApiClient.multipartDio.postUri<Map<String, dynamic>>(
        uri,
        data: fd,
        options: opts,
      );
    }

    try {
      final response = await postUpload(root);
      final data = response.data;
      if (data == null) {
        throw Exception('Пустой ответ загрузки стори');
      }
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) {
        final alt = _alternateOriginFor405(root);
        if (alt != root) {
          final response = await postUpload(alt);
          final data = response.data;
          if (data == null) {
            throw Exception('Пустой ответ загрузки стори');
          }
          return data;
        }
      }
      rethrow;
    }
  }

  Future<void> deleteStory(int storyId) async {
    await _dio.delete<void>(
      '/stories/$storyId',
      options: Options(headers: await _authHeaders()),
    );
  }
}
