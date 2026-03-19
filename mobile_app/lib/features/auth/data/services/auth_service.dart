import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class AuthService {
  final Dio _dio = ApiClient.dio;

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    await _dio.post(
      '/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = response.data;

    String? token;

    if (data is Map<String, dynamic>) {
      token = data['access_token']?.toString();
    } else if (data is Map) {
      token = data['access_token']?.toString();
    }

    if (token == null || token.isEmpty) {
      throw Exception('Сервер не вернул access_token');
    }

    await SecureStorageService.saveAccessToken(token);
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.get(
      '/users/me',
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

    throw Exception('Неожиданный формат ответа /users/me');
  }
}