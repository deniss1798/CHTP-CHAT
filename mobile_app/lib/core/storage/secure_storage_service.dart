import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String accessTokenKey = 'access_token';

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: accessTokenKey);
  }

  static Future<void> deleteAccessToken() async {
    await _storage.delete(key: accessTokenKey);
  }
}