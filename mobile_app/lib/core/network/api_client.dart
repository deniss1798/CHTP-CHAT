import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';

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
      'Type: ${err.type}  status: ${err.response?.statusCode}\n'
      'Message: ${err.message}\n'
      'Response: ${_redact(err.response?.data)}',
    );

    handler.next(err);
  }
}

class ApiClient {
  /// См. [resolvedApiBaseUrl] — `dart-define`, затем `api_base_url.txt` рядом с exe (Windows/macOS/Linux).
  static String get baseUrl => resolvedApiBaseUrl;

  static Dio? _dio;
  static Dio get dio {
    if (_dio != null) {
      return _dio!;
    }
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(minutes: 5),
      ),
    );
    _dio!.interceptors.addAll([
      _MultipartContentTypeInterceptor(),
      if (kDebugMode ||
          kProfileMode ||
          bool.fromEnvironment('API_LOG', defaultValue: false))
        ApiLoggerInterceptor(),
    ]);
    return _dio!;
  }

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
          if (kDebugMode ||
              kProfileMode ||
              bool.fromEnvironment('API_LOG', defaultValue: false))
            ApiLoggerInterceptor(),
        ]);
  }
}