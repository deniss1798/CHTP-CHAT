import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class StoriesService {
  final Dio _dio = ApiClient.dio;

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
    final form = FormData.fromMap({
      'media_type': mediaType,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/stories',
      data: form,
      options: Options(
        headers: await _authHeaders(),
        sendTimeout: const Duration(minutes: 5),
      ),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Пустой ответ загрузки стори');
    }
    return data;
  }

  Future<void> deleteStory(int storyId) async {
    await _dio.delete<void>(
      '/stories/$storyId',
      options: Options(headers: await _authHeaders()),
    );
  }
}
