import 'package:flutter/foundation.dart';

/// Запрос открыть чат извне (например FCM), когда используется [DesktopChatsShell].
class DesktopChatOpenRequest {
  const DesktopChatOpenRequest({
    required this.chatId,
    required this.title,
    required this.chatType,
    this.avatarUrl,
  });

  final int chatId;
  final String title;
  final String chatType;
  final String? avatarUrl;
}

final ValueNotifier<DesktopChatOpenRequest?> desktopChatOpenRequest =
    ValueNotifier<DesktopChatOpenRequest?>(null);
