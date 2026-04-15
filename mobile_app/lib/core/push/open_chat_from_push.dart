import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/desktop_chat_session.dart';
import '../../core/platform/desktop_layout.dart';
import '../../features/chats/presentation/screens/chat_detail_screen.dart';

/// Открыть чат из FCM / локального уведомления (мобильный или десктоп).
void openChatFromPushPayload(PendingPushPayload payload) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;

  if (isDesktopMessengerLayout) {
    desktopChatOpenRequest.value = DesktopChatOpenRequest(
      chatId: payload.chatId,
      title: 'Чат',
      chatType: 'private',
      avatarUrl: payload.avatarUrl,
    );
    return;
  }

  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => ChatDetailScreen(
        chatId: payload.chatId,
        title: 'Чат',
        chatType: 'private',
        avatarUrl: payload.avatarUrl,
      ),
    ),
  );
}
