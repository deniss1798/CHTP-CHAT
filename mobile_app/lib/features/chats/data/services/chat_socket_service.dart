import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/storage/secure_storage_service.dart';

class ChatSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messagesStream => _messageController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required int chatId,
    required String baseHttpUrl,
  }) async {
    await disconnect();

    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final uri = _buildWsUri(
      baseHttpUrl: baseHttpUrl,
      chatId: chatId,
      token: token,
    );

    _channel = WebSocketChannel.connect(uri);

    _subscription = _channel!.stream.listen(
      (event) {
        try {
          final decoded = jsonDecode(event);

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

  /// JWT в query должен кодироваться (`=`, `+`, `&`), иначе WS не подключается — не приходят печать/прочтения.
  Uri _buildWsUri({
    required String baseHttpUrl,
    required int chatId,
    required String token,
  }) {
    final base = baseHttpUrl.trim();
    final root = Uri.parse(base.endsWith('/') ? base : '$base/');
    final resolved = root.resolve('ws/chat/$chatId');
    return Uri(
      scheme: root.scheme == 'https' ? 'wss' : 'ws',
      host: resolved.host,
      port: resolved.hasPort ? resolved.port : null,
      path: resolved.path,
      queryParameters: {'token': token},
    );
  }

  void sendTyping(bool typing) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode({'type': 'typing', 'typing': typing}));
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