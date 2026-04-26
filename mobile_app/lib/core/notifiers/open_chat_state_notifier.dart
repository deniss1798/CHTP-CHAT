import 'package:flutter/foundation.dart';

final ValueNotifier<int?> openChatIdNotifier = ValueNotifier<int?>(null);

bool isChatOpenNow(int chatId) => openChatIdNotifier.value == chatId;

void markChatOpen(int chatId) {
  openChatIdNotifier.value = chatId;
}

void clearOpenChat(int chatId) {
  if (openChatIdNotifier.value == chatId) {
    openChatIdNotifier.value = null;
  }
}
