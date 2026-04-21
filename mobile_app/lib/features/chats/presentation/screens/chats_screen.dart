import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
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
import '../widgets/chats_list.dart';
import '../widgets/chats_loading_state.dart';
import '../widgets/chats_search_field.dart';
import 'chat_detail_screen.dart';
import 'group_chat_create_screen.dart';
import 'user_picker_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    this.embedded = false,
    this.selectedChatId,
    this.onChatSelected,
  });

  final bool embedded;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _logout() async {
    await _controller.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
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
          subtitle: '',
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
          subtitle: '',
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
        onRetry: () => _controller.refresh(),
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
                          widget.embedded ? 12 : 20,
                          widget.embedded ? 14 : 18,
                          widget.embedded ? 12 : 20,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChatsAppBar(
                              onOpenSettings: _openSettings,
                              onLogout: _logout,
                            ),
                            const SizedBox(height: 18),
                            ChatsSearchField(
                              onChanged: _controller.setSearchQuery,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: _buildBody(state, items),
                      ),
                    ],
                  ),
                  Positioned(
                    right: widget.embedded ? 12 : 20,
                    bottom: widget.embedded ? 16 : 20,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openCreateChatSheet,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Ink(
                          width: AppSizes.fab,
                          height: AppSizes.fab,
                          decoration: BoxDecoration(
                            gradient: AppGradients.accentPanel,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.accentFab(),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: AppColors.textOnAccent,
                              size: 24,
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
