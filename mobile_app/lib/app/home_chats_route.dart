import 'package:flutter/widgets.dart';

import '../core/platform/desktop_layout.dart';
import '../features/chats/presentation/screens/chats_screen.dart';
import 'desktop_chats_shell.dart';

/// Главный экран после входа: на десктопе — две колонки, на телефоне — только список.
Widget buildHomeChatsScreen() {
  if (isDesktopMessengerLayout) {
    return const DesktopChatsShell();
  }
  return const ChatsScreen();
}
