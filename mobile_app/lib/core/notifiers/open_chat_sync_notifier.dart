import 'package:flutter/foundation.dart';

/// Запрос догрузить ленту открытого чата (когда сработал inbox, а /ws/chat мог пропустить).
final ValueNotifier<OpenChatSyncRequest?> openChatSyncNotifier =
    ValueNotifier<OpenChatSyncRequest?>(null);

class OpenChatSyncRequest {
  OpenChatSyncRequest(this.chatId)
      : nonce = DateTime.now().microsecondsSinceEpoch;

  final int chatId;
  final int nonce;
}

void requestOpenChatMessagesSync(int chatId) {
  openChatSyncNotifier.value = OpenChatSyncRequest(chatId);
}
