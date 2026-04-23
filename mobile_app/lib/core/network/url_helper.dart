import 'api_client.dart';

class UrlHelper {
  /// Тот же хост/порт, что у [ApiClient.baseUrl] — медиа с API (нужен Bearer).
  /// Публичные S3/MinIO URL (другой хост или порт) с Bearer часто отдают 4xx/пусто.
  static bool isSameServerAsApi(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return false;
    final base = Uri.parse(ApiClient.baseUrl);
    return u.host == base.host && u.port == base.port;
  }

  static String? absoluteMediaUrl(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    if (raw.startsWith('/')) {
      return '${ApiClient.baseUrl}$raw';
    }

    return '${ApiClient.baseUrl}/$raw';
  }
}