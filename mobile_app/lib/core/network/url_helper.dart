import 'api_client.dart';

class UrlHelper {
  /// Тот же **хост**, что у API (порт может отличаться: nginx :80 и uvicorn :8000).
  /// Тогда качаем через Dio с Bearer; иначе открываем внешним браузером без заголовков.
  static bool isSameServerAsApi(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return false;
    final base = Uri.parse(ApiClient.baseUrl);
    return u.host.toLowerCase() == base.host.toLowerCase();
  }

  /// Статика `/media/...` на том же бэкенде, но URL пришёл с другим хостом (localhost vs 10.0.2.2).
  /// Переписываем origin на [ApiClient.baseUrl], путь и query сохраняем.
  static String rewriteStaticMediaToApiOrigin(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasScheme || u.host.isEmpty) return url;
    if (!u.path.startsWith('/media/')) return url;
    if (isSameServerAsApi(url)) return url;
    final origin = Uri.parse(ApiClient.baseUrl).origin;
    final q = u.hasQuery ? '?${u.query}' : '';
    return '$origin${u.path}$q';
  }

  static String? absoluteMediaUrl(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return rewriteStaticMediaToApiOrigin(raw);
    }

    if (raw.startsWith('/')) {
      if (raw.startsWith('/media/')) {
        final origin = Uri.parse(ApiClient.baseUrl).origin;
        return '$origin$raw';
      }
      return '${ApiClient.baseUrl}$raw';
    }

    return '${ApiClient.baseUrl}/$raw';
  }
}