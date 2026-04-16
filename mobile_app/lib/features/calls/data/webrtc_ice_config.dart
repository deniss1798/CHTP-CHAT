import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// ICE: по умолчанию [resolveIceServerConfig] → `GET /webrtc/ice` (временный TURN с бэкенда).
///
/// Аварийный путь — [buildIceServerConfigFromDartDefine]: STUN (Google) + опциональный TURN
/// через `--dart-define` (локальная отладка без API или при ошибке сети).
/// `--dart-define=WEBRTC_USE_API_ICE=false` — только dart-define, без запроса к API.
String? _stunUrlFromTurnUrl(String raw) {
  final u = raw.split('?').first.trim();
  if (u.startsWith('turn:')) {
    return 'stun:${u.substring('turn:'.length)}';
  }
  if (u.startsWith('turns:')) {
    return 'stun:${u.substring('turns:'.length)}';
  }
  return null;
}

/// Только STUN по умолчанию + опциональный TURN из `--dart-define` (без API).
/// Для продакшена предпочтительнее [resolveIceServerConfig].
List<Map<String, dynamic>> buildIceServerConfigFromDartDefine() {
  final defaultStun = <Map<String, dynamic>>[
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  const turnUrlsRaw = String.fromEnvironment('WEBRTC_TURN_URLS');
  const turnUser = String.fromEnvironment('WEBRTC_TURN_USERNAME');
  const turnCred = String.fromEnvironment('WEBRTC_TURN_CREDENTIAL');

  final urls = turnUrlsRaw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (urls.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'WebRTC: только STUN. Если звука нет за NAT — задайте WEBRTC_TURN_URLS (+ логин/пароль при необходимости).',
      );
    }
    return List.from(defaultStun);
  }

  final servers = <Map<String, dynamic>>[];
  final ownStun = _stunUrlFromTurnUrl(urls.first);
  if (ownStun != null) {
    servers.add({'urls': ownStun});
  }
  servers.addAll(defaultStun);

  void addTurnEntry(String url, {required bool withAuth}) {
    if (withAuth && turnUser.isNotEmpty && turnCred.isNotEmpty) {
      servers.add({
        'urls': url,
        'username': turnUser,
        'credential': turnCred,
      });
    } else if (!withAuth) {
      servers.add({'urls': url});
    }
  }

  if (turnUser.isNotEmpty && turnCred.isNotEmpty) {
    for (final u in urls) {
      addTurnEntry(u, withAuth: true);
      // Часть сетей (моб. операторы) режет UDP — дублируем TURN по TCP.
      if (u.startsWith('turn:') && !u.contains('transport=')) {
        addTurnEntry('$u?transport=tcp', withAuth: true);
      }
    }
  } else {
    for (final u in urls) {
      addTurnEntry(u, withAuth: false);
      if (u.startsWith('turn:') && !u.contains('transport=')) {
        addTurnEntry('$u?transport=tcp', withAuth: false);
      }
    }
  }

  if (kDebugMode && urls.isNotEmpty) {
    debugPrint('WebRTC ICE: TURN задан (${urls.length} URL + при необходимости TCP).');
  }

  return servers;
}
