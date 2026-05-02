import 'package:flutter/material.dart';

import 'theme/design_tokens.dart';
import '../core/notifiers/chats_list_refresh_notifier.dart';
import '../features/chats/presentation/screens/user_picker_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import 'desktop_chats_shell.dart';
import 'desktop_chat_session.dart';
import 'widgets/messenger_nav_rail.dart';

/// Трёхколоночный макет как в дизайне: [нав-рейл | рабочая зона] с вкладками
/// «Чаты | Контакты | Настройки»; список чатов + чат остаётся вложенным в вкладку «Чаты».
class MessengerDesktopShell extends StatefulWidget {
  const MessengerDesktopShell({super.key});

  @override
  State<MessengerDesktopShell> createState() => _MessengerDesktopShellState();
}

class _MessengerDesktopShellState extends State<MessengerDesktopShell> {
  int _section = MessengerNavRail.chatsIndex;

  void _onChatCreatedFromPicker({
    required int chatId,
    required String title,
  }) {
    desktopChatOpenRequest.value = DesktopChatOpenRequest(
      chatId: chatId,
      title: title,
      chatType: 'private',
      avatarUrl: null,
    );
    requestChatsListRefresh();
    setState(() {
      _section = MessengerNavRail.chatsIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Web/первый кадр иногда даёт 0 или infinity — иначе рейл схлопывается.
          final raw = constraints.maxHeight;
          final h = raw.isFinite && raw >= 32
              ? raw
              : MediaQuery.sizeOf(context).height;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: MessengerNavRail.railWidth,
                height: h,
                child: MessengerNavRail(
                  railHeight: h,
                  selectedIndex: _section,
                  onDestinationSelected: (i) {
                    setState(() => _section = i);
                  },
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppGradients.background,
                  ),
                  child: IndexedStack(
                    index: _section,
                    sizing: StackFit.expand,
                    children: [
                      const DesktopChatsShell(shellListMode: true),
                      UserPickerScreen(
                        embedded: true,
                        onPrivateChatCreated: _onChatCreatedFromPicker,
                      ),
                      const SettingsScreen(embedded: true),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
