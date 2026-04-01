import 'api_client.dart';

class UrlHelper {
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