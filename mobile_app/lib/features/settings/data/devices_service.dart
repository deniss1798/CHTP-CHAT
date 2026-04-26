import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

class DevicesService {
  final Dio _dio = ApiClient.dio;

  Future<Options> _authorizedOptions() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final response = await _dio.get(
      '/devices',
      options: await _authorizedOptions(),
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Future<void> revokeDevice(int deviceId) async {
    await _dio.delete(
      '/devices/$deviceId',
      options: await _authorizedOptions(),
    );
  }
}
