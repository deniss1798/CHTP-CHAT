import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'webrtc_ice_config.dart';

/// Кэш ICE с бэкенда (`GET /webrtc/ice`): временные TURN-учётки, без статических паролей в сборке.
class IceConfigService {
  IceConfigService._();

  static final IceConfigService instance = IceConfigService._();

  List<Map<String, dynamic>>? _cached;
  DateTime? _validUntil;
  Future<List<Map<String, dynamic>>>? _inFlight;

  static const _refreshBuffer = Duration(seconds: 90);

  void clearCache() {
    _cached = null;
    _validUntil = null;
    _inFlight = null;
  }

  /// Предзагрузка после логина (не блокирует UI при ошибке).
  Future<void> prefetch() async {
    try {
      await getServers();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IceConfigService.prefetch: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getServers() async {
    if (_cached != null &&
        _validUntil != null &&
        DateTime.now().isBefore(_validUntil!)) {
      return _cached!;
    }

    if (_inFlight != null) {
      return _inFlight!;
    }

    _inFlight = _fetch();
    try {
      final list = await _inFlight!;
      _cached = list;
      return list;
    } finally {
      _inFlight = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      return buildIceServerConfigFromDartDefine();
    }

    final dio = ApiClient.dio;
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/webrtc/ice',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final data = response.data;
      if (data == null) {
        return buildIceServerConfigFromDartDefine();
      }

      final raw = data['ice_servers'];
      if (raw is! List) {
        return buildIceServerConfigFromDartDefine();
      }

      final servers = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          servers.add(_normalizeServer(Map<String, dynamic>.from(item)));
        }
      }

      if (servers.isEmpty) {
        return buildIceServerConfigFromDartDefine();
      }

      final expiresAt = data['expires_at'];
      int? exp;
      if (expiresAt is int) {
        exp = expiresAt;
      } else if (expiresAt is num) {
        exp = expiresAt.toInt();
      }

      if (exp != null && exp > 0) {
        final absolute = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        _validUntil = absolute.subtract(_refreshBuffer);
      } else {
        final ttl = data['ttl_seconds'];
        final ttlSec = ttl is int ? ttl : (ttl is num ? ttl.toInt() : 3600);
        final refreshIn = (ttlSec - 120).clamp(60, 86400);
        _validUntil = DateTime.now().add(Duration(seconds: refreshIn));
      }

      final vu = _validUntil!;
      if (vu.isBefore(DateTime.now())) {
        _validUntil = DateTime.now().add(const Duration(minutes: 5));
      }

      if (kDebugMode) {
        debugPrint('IceConfigService: loaded ${servers.length} ICE server(s) from API');
      }
      return servers;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('IceConfigService: API failed, fallback to dart-define — $e');
      }
      return buildIceServerConfigFromDartDefine();
    }
  }

  Map<String, dynamic> _normalizeServer(Map<String, dynamic> m) {
    final urls = m['urls'];
    if (urls is List) {
      m['urls'] = urls.map((e) => e.toString()).toList();
    }
    if (m['username'] == null) {
      m.remove('username');
      m.remove('credential');
    }
    return m;
  }
}

/// Сборка ICE: API (JWT) + кэш, иначе STUN/TURN из dart-define (dev / аварийный fallback).
Future<List<Map<String, dynamic>>> resolveIceServerConfig() async {
  const useApi = bool.fromEnvironment('WEBRTC_USE_API_ICE', defaultValue: true);
  if (!useApi) {
    return buildIceServerConfigFromDartDefine();
  }
  return IceConfigService.instance.getServers();
}
