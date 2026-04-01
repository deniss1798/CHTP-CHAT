import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/session/current_user_store.dart';

class AuthService {
  final Dio _dio = ApiClient.dio;

  Future<String> requestEmailCode({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/request-email-code',
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    final data = response.data;

    String? code;

    if (data is Map<String, dynamic>) {
      code = data['code']?.toString();
    } else if (data is Map) {
      code = data['code']?.toString();
    }

    if (code == null || code.isEmpty) {
      throw Exception('Сервер не вернул код подтверждения');
    }

    return code;
  }

  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final response = await _dio.post(
      '/auth/verify-email-code',
      data: {
        'email': email,
        'code': code,
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
    await _registerDeviceToken(token);
    await getMe(forceRefresh: true);
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
    await _registerDeviceToken(token);
    await getMe(forceRefresh: true);
  }

  Future<void> _registerDeviceToken(String accessToken) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      print('FCM token is null or empty, skip device registration');
      return;
    }

    await _dio.post(
      '/devices/register-token',
      data: {
        'token': fcmToken,
        'platform': 'android',
        'device_name': 'android_emulator',
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _dio.post(
          '/devices/register-token',
          data: {
            'token': newToken,
            'platform': 'android',
            'device_name': 'android_emulator',
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          ),
        );
      } catch (e) {
        print('Failed to refresh device token on backend: $e');
      }
    });
  }

Future<Map<String, dynamic>> getMe({bool forceRefresh = false}) async {
  if (!forceRefresh && CurrentUserStore.user != null) {
    return CurrentUserStore.user!;
  }

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
    CurrentUserStore.setUser(data);
    return data;
  }

  if (data is Map) {
    final mapped = Map<String, dynamic>.from(data);
    CurrentUserStore.setUser(mapped);
    return mapped;
  }

  throw Exception('Неожиданный формат ответа /users/me');
}
}