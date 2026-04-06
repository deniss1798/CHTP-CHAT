import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiLoggerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['start_time'] = DateTime.now().millisecondsSinceEpoch;

    debugPrint(
      '[API START] ${options.method} ${options.uri}\n'
      'Headers: ${options.headers}\n'
      'Query: ${options.queryParameters}\n'
      'Data: ${options.data}',
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
      'Response: ${response.data}',
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
      'Response: ${err.response?.data}',
    );

    handler.next(err);
  }
}

class ApiClient {
  static const String baseUrl = 'http://83.217.201.40';

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      // Загрузка фото/видео (до десятков МБ) по мобильной сети часто > 15 с
      sendTimeout: const Duration(minutes: 5),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  )..interceptors.add(ApiLoggerInterceptor());
}