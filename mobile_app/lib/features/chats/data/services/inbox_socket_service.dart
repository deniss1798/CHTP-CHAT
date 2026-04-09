import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/storage/secure_storage_service.dart';

/// События для списка чатов (typing и др.) без открытого чата.
class InboxSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({required String baseHttpUrl}) async {
    await disconnect();

    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final uri = _buildWsUri(baseHttpUrl: baseHttpUrl, token: token);
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(const Duration(seconds: 20));
    } catch (_) {
      try {
        await channel.sink.close();
      } catch (_) {}
      rethrow;
    }

    _channel = channel;

    _subscription = _channel!.stream.listen(
      (event) {
        try {
          final String text;
          if (event is String) {
            text = event;
          } else if (event is List<int>) {
            text = utf8.decode(event);
          } else {
            text = event.toString();
          }
          final decoded = jsonDecode(text);

          if (decoded is Map<String, dynamic>) {
            _messageController.add(decoded);
          } else if (decoded is Map) {
            _messageController.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      },
      onError: (_) {
        _clearChannel();
      },
      onDone: _clearChannel,
      cancelOnError: false,
    );
  }

  void _clearChannel() {
    _channel = null;
  }

  Uri _buildWsUri({
    required String baseHttpUrl,
    required String token,
  }) {
    final base = baseHttpUrl.trim();
    final httpUri = Uri.parse(base.isEmpty ? 'http://localhost' : base);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    var pathPrefix = httpUri.path;
    if (pathPrefix.length > 1 && pathPrefix.endsWith('/')) {
      pathPrefix = pathPrefix.substring(0, pathPrefix.length - 1);
    }
    if (pathPrefix == '/') {
      pathPrefix = '';
    }
    final wsPath =
        pathPrefix.isEmpty ? '/ws/inbox' : '$pathPrefix/ws/inbox';
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: wsPath,
      queryParameters: {'token': token},
    );
  }

  void sendPing() {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode({'type': 'ping'}));
    } catch (_) {}
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _clearChannel();
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
