import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_chat_session.dart';
import 'theme/app_colors.dart';
import 'theme/app_icons.dart';
import 'theme/app_shadows.dart';
import 'theme/design_tokens.dart';
import 'widgets/app_surface.dart';
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
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: AppSurface(
            tone: AppSurfaceTone.elevated,
            radius: AppRadius.xxl,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            shadow: [...AppShadows.card, ...AppShadows.accentStroke],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: AppGradients.accentPanel,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppShadows.primaryButton,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    AppIcons.chat,
                    size: 34,
                    color: AppColors.textOnAccent,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Выберите чат',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Слева уже собраны все переписки. Откройте нужный диалог, и справа появится полная рабочая сцена общения.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
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
