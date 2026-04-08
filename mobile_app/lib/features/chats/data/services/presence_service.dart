import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

/// Периодический ping «я в сети» для поля users.last_seen_at на сервере.
class PresenceService {
  final Dio _dio = ApiClient.dio;

  Future<void> ping() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      await _dio.post<void>(
        '/users/me/presence',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          // 404 — на сервере ещё не задеплоен этот маршрут; не считаем ошибкой.
          validateStatus: (s) =>
              s != null && (s == 204 || s == 200 || s == 404),
        ),
      );
    } catch (_) {}
  }
}
