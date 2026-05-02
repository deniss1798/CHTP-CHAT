import 'package:flutter/widgets.dart';

import '../core/platform/desktop_layout.dart';
import '../features/chats/presentation/screens/chats_screen.dart';
import 'messenger_desktop_shell.dart';

/// Главный экран после входа: на десктопе — боковая навигация + список чатов + чат.
Widget buildHomeChatsScreen() {
  if (isDesktopMessengerLayout) {
    return const MessengerDesktopShell();
  }
  return const ChatsScreen();
}
