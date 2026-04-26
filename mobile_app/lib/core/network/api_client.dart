import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Глобальный `Content-Type: application/json` ломает multipart: boundary не подставляется,
/// nginx/FastAPI могут ответить 405 / не распарсить тело. Для FormData не задаём Content-Type вручную.
class _MultipartContentTypeInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data is FormData) {
      options.headers.remove(Headers.contentTypeHeader);
    }
    handler.next(options);
  }
}

class ApiLoggerInterceptor extends Interceptor {
  static const _sensitiveKeys = {
    'authorization',
    'access_token',
    'refresh_token',
    'token',
    'password',
    'verification_code',
    'code',
    'media_url',
    'avatar_url',
  };

  Object? _redact(Object? value) {
    if (value is Map) {
      return value.map((key, item) {
        final normalizedKey = key.toString().toLowerCase();
        return MapEntry(
          key,
          _sensitiveKeys.contains(normalizedKey) ? '***' : _redact(item),
        );
      });
    }

    if (value is Iterable && value is! String) {
      return value.map(_redact).toList();
    }

    if (value is String) {
      return value
          .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+'), 'Bearer ***')
          .replaceAllMapped(
            RegExp(r'([?&](?:token|access_token|refresh_token|password|code)=)[^&\s]+'),
            (match) => '${match.group(1)}***',
          )
          .replaceAll(
            RegExp(r'https?://[^\s]+(?:X-Amz-Signature|Signature|token|access_token)=[^\s]+'),
            '***',
          );
    }

    return value;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['start_time'] = DateTime.now().millisecondsSinceEpoch;

    debugPrint(
      '[API START] ${options.method} ${options.uri}\n'
      'Headers: ${_redact(options.headers)}\n'
      'Query: ${_redact(options.queryParameters)}\n'
      'Data: ${_redact(options.data)}',
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final start = response.requestOptions.extra['start_time'] as int?;
    final duration = start == null
        ? 'unknown'
        : '${DateTime.now().millisecondsSinceEpoch - start} ms';

    debugPrint(
      '[API END] ${response.requestOptions.method} ${response.requestOptions.uri}\n'
      'Status: ${response.statusCode}\n'
      'Duration: $duration\n'
      'Response: ${_redact(response.data)}',
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final start = err.requestOptions.extra['start_time'] as int?;
    final duration = start == null
        ? 'unknown'
        : '${DateTime.now().millisecondsSinceEpoch - start} ms';

    debugPrint(
      '[API ERROR] ${err.requestOptions.method} ${err.requestOptions.uri}\n'
      'Duration: $duration\n'
      'Message: ${err.message}\n'
      'Response: ${_redact(err.response?.data)}',
    );

    handler.next(err);
  }
}

class ApiClient {
  /// Базовый URL REST API без завершающего `/`.
  /// Сборка: `flutter run --dart-define=API_BASE_URL=https://example.com/api`
  static String get baseUrl {
    const env = String.fromEnvironment('API_BASE_URL');
    // Бэкенд дублирует роуты с префиксом /api (см. main.py). За nginx без /api часто 404.
    final raw =
        env.trim().isNotEmpty ? env.trim() : 'http://127.0.0.1:8000/api';
    if (raw.endsWith('/')) {
      return raw.substring(0, raw.length - 1);
    }
    return raw;
  }

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      // Загрузка фото/видео (до десятков МБ) по мобильной сети часто > 15 с
      sendTimeout: const Duration(minutes: 5),
    ),
  )..interceptors.addAll([
          _MultipartContentTypeInterceptor(),
          ApiLoggerInterceptor(),
        ]);

  /// Отдельный клиент для multipart: без `baseUrl`, запросы только через [Dio.postUri].
  /// Так надёжнее на Windows и не смешивается с опциями основного [dio].
  static Dio? _multipartDio;
  static Dio get multipartDio {
    return _multipartDio ??= Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(minutes: 5),
      ),
    )..interceptors.addAll([
          _MultipartContentTypeInterceptor(),
          ApiLoggerInterceptor(),
        ]);
  }
}