import 'dart:async';

import '../../data/services/chat_socket_service.dart';

class ChatSocketController {
  Future<StreamSubscription<Map<String, dynamic>>?> connect({
    required ChatSocketService service,
    required int chatId,
    required String baseHttpUrl,
    required void Function(Map<String, dynamic>) onMessage,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await service.connect(
          chatId: chatId,
          baseHttpUrl: baseHttpUrl,
        );

        return service.messagesStream.listen(onMessage);
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return null;
  }
}
