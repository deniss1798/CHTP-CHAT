import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class ProfileService {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> getMe() async {
    final token = await SecureStorageService.getAccessToken();

    final response = await _dio.get(
      '/users/me',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> uploadMyAvatar(File file) async {
    final token = await SecureStorageService.getAccessToken();

    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
    final mimeParts = mimeType.split('/');

    final fileName = file.path.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: MediaType(
          mimeParts.first,
          mimeParts.length > 1 ? mimeParts.last : 'jpeg',
        ),
      ),
    });

    final response = await _dio.patch(
      '/users/me/avatar',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getUser(int userId) async {
    final token = await SecureStorageService.getAccessToken();
    final response = await _dio.get(
      '/users/$userId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteMyAccount() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    await _dio.delete(
      '/users/me',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }
}