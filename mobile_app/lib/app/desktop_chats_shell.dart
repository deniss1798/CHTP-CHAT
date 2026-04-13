import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_chat_session.dart';
import 'theme/app_colors.dart';
import 'theme/app_icons.dart';
import '../features/chats/presentation/screens/chat_detail_screen.dart';
import '../features/chats/presentation/screens/chats_screen.dart';

const String _kPrefsLeftWidth = 'desktop_chats_left_width';

/// Слева список чатов, справа открытый чат; ширина левой колонки перетаскивается.
class DesktopChatsShell extends StatefulWidget {
  const DesktopChatsShell({super.key});

  @override
  State<DesktopChatsShell> createState() => _DesktopChatsShellState();
}

class _DesktopChatsShellState extends State<DesktopChatsShell> {
  double _leftPanelWidth = 340;
  int? _selectedChatId;
  String _selectedTitle = '';
  String _selectedChatType = 'private';
  String? _selectedAvatarUrl;

  @override
  void initState() {
    super.initState();
    desktopChatOpenRequest.addListener(_onDesktopOpenRequest);
    _loadSavedWidth();
  }

  Future<void> _loadSavedWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble(_kPrefsLeftWidth);
    if (!mounted || w == null) return;
    setState(() {
      _leftPanelWidth = w;
    });
  }

  Future<void> _persistWidth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefsLeftWidth, _leftPanelWidth);
  }

  void _onDesktopOpenRequest() {
    final req = desktopChatOpenRequest.value;
    if (req == null) return;
    setState(() {
      _selectedChatId = req.chatId;
      _selectedTitle = req.title;
      _selectedChatType = req.chatType;
      _selectedAvatarUrl = req.avatarUrl;
    });
    desktopChatOpenRequest.value = null;
  }

  @override
  void dispose() {
    desktopChatOpenRequest.removeListener(_onDesktopOpenRequest);
    super.dispose();
  }

  void _onChatSelected({
    required int chatId,
    required String title,
    required String chatType,
    String? avatarUrl,
  }) {
    setState(() {
      _selectedChatId = chatId;
      _selectedTitle = title;
      _selectedChatType = chatType;
      _selectedAvatarUrl = avatarUrl;
    });
  }

  void _clearChat() {
    setState(() {
      _selectedChatId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        const minLeft = 260.0;
        final maxLeft = (maxW * 0.55).clamp(minLeft, 560.0);
        final left = _leftPanelWidth.clamp(minLeft, maxLeft);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              SizedBox(
                width: left,
                child: ChatsScreen(
                  embedded: true,
                  selectedChatId: _selectedChatId,
                  onChatSelected: _onChatSelected,
                ),
              ),
              _SplitDragHandle(
                onDrag: (dx) {
                  setState(() {
                    _leftPanelWidth =
                        (_leftPanelWidth + dx).clamp(minLeft, maxLeft);
                  });
                },
                onDragEnd: _persistWidth,
              ),
              Expanded(
                child: _selectedChatId == null
                    ? _DesktopEmptyChatPane()
                    : ChatDetailScreen(
                        key: ValueKey(_selectedChatId),
                        chatId: _selectedChatId!,
                        title: _selectedTitle,
                        chatType: _selectedChatType,
                        avatarUrl: _selectedAvatarUrl,
                        onBackOverride: _clearChat,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopEmptyChatPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.chat,
              size: 72,
              color: AppColors.textMuted.withAlpha(180),
            ),
            const SizedBox(height: 20),
            Text(
              'Выберите чат',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Слева список переписок',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitDragHandle extends StatelessWidget {
  const _SplitDragHandle({
    required this.onDrag,
    required this.onDragEnd,
  });

  final void Function(double deltaDx) onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        child: SizedBox(
          width: 8,
          child: Center(
            child: Container(
              width: 1,
              color: Colors.white.withAlpha(28),
            ),
          ),
        ),
      ),
    );
  }
}
