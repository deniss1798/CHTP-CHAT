import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

class NotificationSettingsService {
  final Dio _dio = ApiClient.dio;

  Future<Options> _authorizedOptions() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<bool> fetchEnabled() async {
    final response = await _dio.get(
      '/notification-settings',
      options: await _authorizedOptions(),
    );
    final data = response.data;
    if (data is Map) {
      return data['notifications_enabled'] != false;
    }
    return true;
  }

  Future<void> updateEnabled(bool enabled) async {
    await _dio.put(
      '/notification-settings',
      data: {'notifications_enabled': enabled},
      options: await _authorizedOptions(),
    );
  }
}
