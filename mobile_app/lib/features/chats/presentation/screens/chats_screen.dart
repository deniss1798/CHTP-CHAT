import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../calls/voice_call_ring.dart';
import '../controller/chats_controller.dart';
import '../models/chat_list_item_model.dart';
import '../models/chats_screen_state.dart';
import '../widgets/chats_app_bar.dart';
import '../widgets/chats_create_sheet.dart';
import '../widgets/chats_empty_state.dart';
import '../widgets/chats_error_state.dart';
import '../widgets/chats_incoming_call_dialogs.dart';
import '../widgets/chats_list_filter_chips.dart';
import '../widgets/chats_list.dart';
import '../widgets/chats_loading_state.dart';
import '../widgets/chats_search_field.dart';
import 'chat_detail_screen.dart';
import 'group_chat_create_screen.dart';
import 'user_picker_screen.dart';
import '../../../stories/presentation/stories_feed_controller.dart';
import '../../../stories/presentation/widgets/stories_strip.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    this.embedded = false,
    this.shellListMode = false,
    this.selectedChatId,
    this.onChatSelected,
  });

  final bool embedded;
  /// См. [DesktopChatsShell.shellListMode] — левая колонка внутри [MessengerDesktopShell].
  final bool shellListMode;
  final int? selectedChatId;
  final void Function({
    required int chatId,
    required String title,
    required String chatType,
    String? avatarUrl,
  })? onChatSelected;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> with WidgetsBindingObserver {
  late final ChatsController _controller = ChatsController(
    onPrivateCallInvite: _handlePrivateCallInvite,
    onGroupCallInvite: _handleGroupCallInvite,
    isChatOpen: (chatId) => widget.embedded && widget.selectedChatId == chatId,
  );

  late final StoriesFeedController _storiesFeedController = StoriesFeedController();

  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.initialize());
    unawaited(_storiesFeedController.load());
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _storiesFeedController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_controller.handleLifecycleChange(state));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );

    if (!mounted) return;
    await _controller.refresh(silent: true);
  }

  Future<void> _openChatFromItem(ChatListItemModel item) async {
    if (widget.embedded && widget.onChatSelected != null) {
      widget.onChatSelected!(
        chatId: item.chatId,
        title: item.title,
        chatType: item.chatType,
        avatarUrl: item.avatarUrl,
      );
      if (!mounted) return;
      await _controller.refresh(silent: true);
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: item.chatId,
          title: item.title,
          chatType: item.chatType,
          avatarUrl: item.avatarUrl,
        ),
      ),
    );

    if (!mounted) return;
    await _controller.refresh(silent: true);
  }

  Future<void> _openCreateChatSheet() async {
    final result = await ChatsCreateSheet.show(context);
    if (!mounted || result == null) return;
    final navigator = Navigator.of(context);

    if (result == 'private') {
      final created = await navigator.push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const UserPickerScreen()),
      );

      await _controller.refresh();
      if (!mounted || created == null) return;

      final chatId = _parseInt(created['chat_id']);
      final chatTitle = (created['chat_title'] ?? 'Чат').toString();
      if (chatId == null) return;

      await _openChatFromItem(
        ChatListItemModel(
          chatId: chatId,
          chatType: 'private',
          title: chatTitle,
          avatarUrl: null,
          lastMessageType: null,
          subtitle: '',
          subtitleGroupAuthor: null,
          subtitleGroupMessageBody: null,
          timeLabel: '',
          unreadCount: 0,
          isOnline: false,
          isSelected: false,
          isTyping: false,
        ),
      );
    }

    if (result == 'group') {
      final created = await navigator.push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const GroupChatCreateScreen()),
      );

      await _controller.refresh();
      if (!mounted || created == null) return;

      final chatId = _parseInt(created['chat_id']);
      final chatTitle = (created['chat_title'] ?? 'Группа').toString();
      if (chatId == null) return;

      await _openChatFromItem(
        ChatListItemModel(
          chatId: chatId,
          chatType: 'group',
          title: chatTitle,
          avatarUrl: null,
          lastMessageType: null,
          subtitle: '',
          subtitleGroupAuthor: null,
          subtitleGroupMessageBody: null,
          timeLabel: '',
          unreadCount: 0,
          isOnline: false,
          isSelected: false,
          isTyping: false,
        ),
      );
    }
  }

  Future<void> _handlePrivateCallInvite(Map<String, dynamic> invite) async {
    if (kIsWeb) return;

    final currentUserId = _controller.currentUserId;
    if (currentUserId == null) return;

    final chatId = _parseInt(invite['chat_id']);
    if (chatId == null) return;
    if (_controller.chatTypeById(chatId) == 'group') return;

    final callerId = _parseInt(invite['user_id']);
    if (callerId == null || callerId == currentUserId) return;

    final callId = invite['call_id']?.toString() ?? '';
    if (callId.isEmpty || !VoiceCallRing.tryStart(callId)) return;

    final title = _controller.titleForChatId(chatId) ?? 'Чат';

    await ChatsIncomingCallDialogs.showPrivateCallInvite(
      context: context,
      chatId: chatId,
      callerId: callerId,
      currentUserId: currentUserId,
      title: title,
      invite: invite,
    );
  }

  Future<void> _handleGroupCallInvite(Map<String, dynamic> invite) async {
    if (kIsWeb) return;

    final currentUserId = _controller.currentUserId;
    if (currentUserId == null) return;

    final chatId = _parseInt(invite['chat_id']);
    if (chatId == null) return;
    if (_controller.chatTypeById(chatId) == 'private') return;

    final callerId = _parseInt(invite['user_id']);
    if (callerId == null || callerId == currentUserId) return;

    final callId = invite['call_id']?.toString() ?? '';
    if (callId.isEmpty || !VoiceCallRing.tryStart(callId)) return;

    final startedByUserId = _parseInt(invite['started_by']) ?? callerId;
    final title = _controller.titleForChatId(chatId) ?? 'Чат';

    await ChatsIncomingCallDialogs.showGroupCallInvite(
      context: context,
      chatId: chatId,
      currentUserId: currentUserId,
      startedByUserId: startedByUserId,
      title: title,
      withVideo: invite['video'] == true,
      invite: invite,
    );
  }

  int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  Widget _buildBody(
    ChatsScreenState state,
    List<ChatListItemModel> items,
  ) {
    if (state.isLoading) {
      return const ChatsLoadingState();
    }

    if (state.error != null) {
      return ChatsErrorState(
        message: state.error!,
        onRetry: () => _controller.retryAfterError(),
      );
    }

    if (items.isEmpty) {
      return const ChatsEmptyState();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (n is ScrollUpdateNotification) {
          final m = n.metrics;
          if (m.pixels >= m.maxScrollExtent - 140) {
            unawaited(_controller.loadMoreChats());
          }
        }
        return false;
      },
      child: ChatsList(
        items: items,
        embedded: widget.embedded,
        bottomPadding: widget.shellListMode ? 12 : null,
        onRefresh: () => _controller.refresh(),
        onTap: _openChatFromItem,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final items =
            _controller.buildVisibleItems(selectedChatId: widget.selectedChatId);

        final useDesktopListChrome = widget.embedded && widget.shellListMode;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: AppScreenBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          widget.embedded ? 12 : 28,
                          widget.embedded ? 14 : 26,
                          widget.embedded ? 12 : 28,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChatsAppBar(
                              shellListMode: widget.shellListMode,
                              onOpenSettings: widget.shellListMode
                                  ? null
                                  : _openSettings,
                            ),
                            const SizedBox(height: 16),
                            ChatsSearchField(
                              focusNode: _searchFocus,
                              showShortcutHint: useDesktopListChrome,
                              onChanged: _controller.setSearchQuery,
                            ),
                            if (useDesktopListChrome) ...[
                              const SizedBox(height: 14),
                              ChatsListFilterChips(
                                value: state.listFilter,
                                onChanged: _controller.setListFilter,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (state.currentUserId != null && state.error == null)
                        AnimatedBuilder(
                          animation: _storiesFeedController,
                          builder: (context, _) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: _storiesFeedController.entries.isEmpty &&
                                        !_storiesFeedController.loading
                                    ? 0
                                    : 6,
                              ),
                              child: StoriesStrip(
                                entries: _storiesFeedController.entries,
                                loading: _storiesFeedController.loading,
                                onRefreshFeed: () =>
                                    _storiesFeedController.load(silent: true),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _buildBody(state, items),
                      ),
                      if (useDesktopListChrome)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _ChatsNewChatBar(
                            onTap: _openCreateChatSheet,
                          ),
                        ),
                    ],
                  ),
                  if (!useDesktopListChrome)
                    Positioned(
                      right: widget.embedded ? 12 : 20,
                      bottom: widget.embedded ? 16 : 20,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openCreateChatSheet,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Ink(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: AppGradients.accentPanel,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accentBright.withValues(alpha: 0.65),
                                width: 1,
                              ),
                              boxShadow: AppShadows.accentFab(),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.add_rounded,
                                color: AppColors.textOnAccent,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatsNewChatBar extends StatelessWidget {
  const _ChatsNewChatBar({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppGradients.accentPanel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accentBright.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: AppShadows.accentFab(),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: Colors.black,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Новый чат',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
