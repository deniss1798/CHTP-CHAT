import 'package:dio/dio.dart';

import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';

class WsTokenService {
  final Dio _dio = ApiClient.dio;

  Future<String> issueWsToken() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.post(
      '/auth/ws-token',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    if (data is Map) {
      final wsToken = data['ws_token']?.toString();
      if (wsToken != null && wsToken.isNotEmpty) {
        return wsToken;
      }
    }
    throw Exception('Сервер не вернул ws_token');
  }
}
