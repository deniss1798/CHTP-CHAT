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

  /// Абсолютный путь `/ws/chat/{id}` + JWT в query (кодирование обязательно).
  Uri _buildWsUri({
    required String baseHttpUrl,
    required int chatId,
    required String token,
  }) {
    final base = baseHttpUrl.trim();
    final httpUri = Uri.parse(base);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: '/ws/chat/$chatId',
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