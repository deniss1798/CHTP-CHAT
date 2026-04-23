import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/formatting/server_time.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/notifiers/chats_list_refresh_notifier.dart';
import '../../../../core/push/local_notifications_service.dart';
import '../../../../core/realtime/chat_ws_contract.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../calls/data/ice_config_service.dart';
import '../../../calls/voice_call_ring.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chats_service.dart';
import '../../data/services/inbox_socket_service.dart';
import '../../data/services/local_chat_state_service.dart';
import '../../data/services/presence_service.dart';
import '../../domain/chat_list_rules.dart';
import '../models/chat_list_item_model.dart';
import '../models/chats_list_filter.dart';
import '../models/chats_screen_state.dart';

typedef ChatsInviteHandler = Future<void> Function(Map<String, dynamic> invite);
typedef OpenChatProbe = bool Function(int chatId);

class ChatsController extends ChangeNotifier {
  ChatsController({
    AuthService? authService,
    ChatsService? chatsService,
    PresenceService? presenceService,
    InboxSocketService? inboxSocket,
    LocalChatStateService? localChatStateService,
    this.onPrivateCallInvite,
    this.onGroupCallInvite,
    this.isChatOpen,
  })  : _authService = authService ?? AuthService(),
        _chatsService = chatsService ?? ChatsService(),
        _presenceService = presenceService ?? PresenceService(),
        _inboxSocket = inboxSocket ?? InboxSocketService(),
        _localChatStateService =
            localChatStateService ?? LocalChatStateService();

  static const Duration _chatsListPollInterval = Duration(seconds: 5);
  static const Duration _typingLabelLifetime = Duration(seconds: 3);

  final AuthService _authService;
  final ChatsService _chatsService;
  final PresenceService _presenceService;
  final InboxSocketService _inboxSocket;
  final LocalChatStateService _localChatStateService;

  final ChatsInviteHandler? onPrivateCallInvite;
  final ChatsInviteHandler? onGroupCallInvite;
  final OpenChatProbe? isChatOpen;

  ChatsScreenState _state = const ChatsScreenState();
  ChatsScreenState get state => _state;

  StreamSubscription<Map<String, dynamic>>? _inboxSubscription;
  Timer? _chatsPollTimer;
  Timer? _presenceTimer;
  Timer? _inboxPingTimer;
  final Map<int, Timer> _typingInboxTimers = {};
  bool _isDisposed = false;

  void _handleChatsRefresh() {
    if (_state.currentUserId == null) return;
    unawaited(refresh(silent: true));
  }

  Future<void> initialize() async {
    chatsListRefreshNotifier.addListener(_handleChatsRefresh);
    _startChatsPolling();
    _startPresenceHeartbeat();
    await _init();
  }

  @override
  void dispose() {
    _isDisposed = true;
    chatsListRefreshNotifier.removeListener(_handleChatsRefresh);
    _chatsPollTimer?.cancel();
    _presenceTimer?.cancel();
    _inboxPingTimer?.cancel();
    unawaited(_inboxSubscription?.cancel() ?? Future<void>.value());
    for (final timer in _typingInboxTimers.values) {
      timer.cancel();
    }
    _typingInboxTimers.clear();
    _inboxSocket.dispose();
    super.dispose();
  }

  int? get currentUserId => _state.currentUserId;

  String? chatTypeById(int chatId) {
    for (final chat in _state.allChats) {
      if (chat.id == chatId) return chat.type;
    }
    return null;
  }

  String? titleForChatId(int chatId) {
    for (final chat in _state.allChats) {
      if (chat.id == chatId) {
        final title = chat.title.trim();
        return title.isNotEmpty ? title : null;
      }
    }
    return null;
  }

  Future<void> handleLifecycleChange(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed || _state.currentUserId == null) {
      return;
    }

    await refresh(silent: true);
    if (!_inboxSocket.isConnected) {
      await _connectInboxWithRetry();
    }
  }

  Future<void> logout() async {
    IceConfigService.instance.clearCache();
    await SecureStorageService.deleteAccessToken();
  }

  void setSearchQuery(String query) {
    final normalized = query.trim().toLowerCase();
    _setState(
      _state.copyWith(
        searchQuery: normalized,
        filteredChats: _applySearchToList(_state.allChats, normalized),
      ),
    );
  }

  void setListFilter(ChatsListFilter filter) {
    if (_state.listFilter == filter) return;
    _setState(_state.copyWith(listFilter: filter));
  }

  bool _chatMatchesListFilter(ChatSummary c) {
    switch (_state.listFilter) {
      case ChatsListFilter.all:
        return true;
      case ChatsListFilter.unread:
        return resolveUnreadCount(
              serverUnreadCount: c.unreadCount,
              currentUserId: _state.currentUserId,
              lastMessageId: c.lastMessageId,
              lastMessageSenderId: c.lastMessageSenderId,
              myLastReadMessageId: c.myLastReadMessageId,
            ) >
            0;
      case ChatsListFilter.groups:
        return c.type == 'group';
    }
  }

  List<ChatListItemModel> buildVisibleItems({int? selectedChatId}) {
    final afterTab = _state.filteredChats
        .where(_chatMatchesListFilter)
        .toList();
    return afterTab.map((chat) {
      final title = resolveChatListTitle(title: chat.title, chatId: chat.id);
      final typingLabel = _state.typingLabelByChatId[chat.id];
      final unreadCount = resolveUnreadCount(
        serverUnreadCount: chat.unreadCount,
        currentUserId: _state.currentUserId,
        lastMessageId: chat.lastMessageId,
        lastMessageSenderId: chat.lastMessageSenderId,
        myLastReadMessageId: chat.myLastReadMessageId,
      );

      final sub = buildChatListSubtitleParts(
        typingLabel: typingLabel,
        chatType: chat.type,
        lastMessage: chat.lastMessage,
        lastMessageType: chat.lastMessageType,
        lastMessageSenderName: chat.lastMessageSenderName,
        lastMessageSenderId: chat.lastMessageSenderId,
        currentUserId: _state.currentUserId,
      );

      return ChatListItemModel(
        chatId: chat.id,
        chatType: chat.type,
        title: title,
        avatarUrl: chat.avatarUrl,
        lastMessageType: chat.lastMessageType,
        subtitle: sub.line,
        subtitleGroupAuthor: sub.groupAuthor,
        subtitleGroupMessageBody: sub.groupMessageBody,
        timeLabel: resolveChatTimeLabel(chat.lastMessageAtRaw),
        unreadCount: unreadCount,
        isOnline: chat.type == 'private' &&
            resolvePeerOnlineFromLastSeen(chat.peerLastSeenAtRaw),
        isSelected: selectedChatId != null && chat.id == selectedChatId,
        isTyping: typingLabel != null,
      );
    }).toList();
  }

  Future<void> refresh({bool silent = false}) async {
    if (_state.currentUserId == null) return;

    if (!silent) {
      _setState(_state.copyWith(isLoading: true, clearError: true));
    }

    try {
      final page = await _chatsService.getChatsPage(
        currentUserId: _state.currentUserId!,
        limit: 50,
        cursor: null,
      );
      var chats = page.chats;
      final localReads = await _localChatStateService.getAllLastReadMessageIds();

      chats = chats.map((chat) {
        final localRead = localReads[chat.id];
        var updated = chat;
        if (localRead != null && localRead > updated.myLastReadMessageId) {
          updated = updated.copyWith(myLastReadMessageId: localRead);
        }

        final unreadCount = resolveUnreadCount(
          serverUnreadCount: updated.unreadCount,
          currentUserId: _state.currentUserId,
          lastMessageId: updated.lastMessageId,
          lastMessageSenderId: updated.lastMessageSenderId,
          myLastReadMessageId: updated.myLastReadMessageId,
        );

        if (updated.unreadCount != unreadCount) {
          updated = updated.copyWith(unreadCount: unreadCount);
        }
        return updated;
      }).toList();

      _setState(
        _state.copyWith(
          allChats: chats,
          filteredChats: _applySearchToList(chats, _state.searchQuery),
          isLoading: false,
          clearError: true,
          chatsNextCursor: page.hasMore ? page.nextCursor : null,
          clearChatsNextCursor: !page.hasMore,
        ),
      );
    } catch (error) {
      if (silent) return;
      _setState(
        _state.copyWith(
          error: _extractLoadChatsErrorMessage(error),
          isLoading: false,
        ),
      );
    }
  }

  Future<void> _init() async {
    try {
      final me = await _authService.getMe();
      final currentUserId = _parseInt(me['id']);

      _setState(
        _state.copyWith(
          currentUserId: currentUserId,
          keepCurrentUserId: false,
        ),
      );

      await refresh();
      if (_state.currentUserId != null) {
        await _connectInboxWithRetry();
      }
    } catch (_) {
      _setState(
        _state.copyWith(
          error: 'Не удалось инициализировать список чатов',
          isLoading: false,
        ),
      );
    }
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceService.ping();
    _presenceTimer = Timer.periodic(const Duration(seconds: 50), (_) {
      _presenceService.ping();
    });
  }

  void _startChatsPolling() {
    _chatsPollTimer?.cancel();
    _chatsPollTimer = Timer.periodic(_chatsListPollInterval, (_) {
      if (_state.currentUserId == null) return;
      unawaited(refresh(silent: true));
    });
  }

  Future<void> _connectInboxWithRetry() async {
    await _inboxSubscription?.cancel();
    _inboxSubscription = null;
    _inboxPingTimer?.cancel();
    _inboxPingTimer = null;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await _inboxSocket.connect(baseHttpUrl: ApiClient.baseUrl);
        _inboxSubscription = _inboxSocket.messagesStream.listen(_onInboxMessage);
        _inboxPingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
          if (!_inboxSocket.isConnected) return;
          _inboxSocket.sendPing();
        });
        if (kDebugMode) {
          debugPrint('ChatsController: inbox WebSocket connected');
        }
        return;
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'ChatsController: inbox connect attempt ${attempt + 1}/5: $error',
          );
        }
        await Future<void>.delayed(
          Duration(milliseconds: 400 + attempt * 350),
        );
      }
    }

    if (kDebugMode) {
      debugPrint('ChatsController: inbox WebSocket failed after retries');
    }
  }

  void _onInboxMessage(Map<String, dynamic> message) {
    final type = message['type']?.toString();

    if (type == 'inbox_new_message') {
      _handleInboxNewMessage(message);
      return;
    }

    if (type == 'group_call_invite') {
      if (onGroupCallInvite != null) {
        unawaited(onGroupCallInvite!(message));
      }
      return;
    }

    if (type == 'call_e2e_hangup') {
      final callId = message['call_id']?.toString() ?? '';
      if (callId.isNotEmpty) {
        VoiceCallRing.dismissIncomingDialog(callId);
      }
      return;
    }

    if (type == 'call_e2e_init') {
      if (onPrivateCallInvite != null) {
        unawaited(onPrivateCallInvite!(message));
      }
      return;
    }

    if (type == ChatWsContract.payloadTypeTyping) {
      _handleTypingEvent(message);
    }
  }

  void _handleInboxNewMessage(Map<String, dynamic> message) {
    final chatId = _parseInt(message['chat_id']);
    if (chatId != null) {
      final viewingThis = isChatOpen?.call(chatId) ?? false;
      if (!viewingThis && LocalNotificationsService.supported) {
        final sender = (message['sender_name'] ?? '').toString().trim();
        final preview = (message['preview'] ?? '').toString().trim();
        final avatarUrl = (message['chat_avatar_url'] ?? '').toString().trim();
        unawaited(
          LocalNotificationsService.instance.showChatMessage(
            notificationId: chatId,
            title: sender.isNotEmpty ? sender : 'Чат',
            body: preview.isNotEmpty ? preview : 'Новое сообщение',
            avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
            chatId: chatId,
            avatarUrlForOpen: avatarUrl.isNotEmpty ? avatarUrl : null,
          ),
        );
      }
      requestChatsListRefresh();
    }
  }

  void _handleTypingEvent(Map<String, dynamic> message) {
    final chatId = _parseInt(message['chat_id']);
    if (chatId == null) return;

    final typing = message['typing'] != false;
    if (!typing) {
      _typingInboxTimers[chatId]?.cancel();
      _typingInboxTimers.remove(chatId);
      final labels = Map<int, String>.from(_state.typingLabelByChatId)
        ..remove(chatId);
      _setState(_state.copyWith(typingLabelByChatId: labels));
      return;
    }

    final username = (message['username'] ?? '').toString().trim();
    final isPrivate = chatTypeById(chatId) == 'private';
    final label = isPrivate
        ? 'Печатает…'
        : (username.isNotEmpty ? '$username печатает…' : 'Печатает…');

    _typingInboxTimers[chatId]?.cancel();
    _typingInboxTimers[chatId] = Timer(_typingLabelLifetime, () {
      final labels = Map<int, String>.from(_state.typingLabelByChatId)
        ..remove(chatId);
      _typingInboxTimers.remove(chatId);
      _setState(_state.copyWith(typingLabelByChatId: labels));
    });

    final labels = Map<int, String>.from(_state.typingLabelByChatId)
      ..[chatId] = label;
    _setState(_state.copyWith(typingLabelByChatId: labels));
  }

  List<ChatSummary> _applySearchToList(
    List<ChatSummary> chats,
    String query,
  ) {
    if (query.isEmpty) return List<ChatSummary>.from(chats);

    return chats.where((chat) {
      final title = resolveChatListTitle(title: chat.title, chatId: chat.id)
          .toLowerCase();
      final subtitle = buildChatListSubtitleParts(
        typingLabel: null,
        chatType: chat.type,
        lastMessage: chat.lastMessage,
        lastMessageType: chat.lastMessageType,
        lastMessageSenderName: chat.lastMessageSenderName,
        lastMessageSenderId: chat.lastMessageSenderId,
        currentUserId: _state.currentUserId,
      ).line.toLowerCase();
      return title.contains(query) || subtitle.contains(query);
    }).toList();
  }

  String _extractLoadChatsErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        return data['detail']?.toString() ??
            data['message']?.toString() ??
            'Не удалось загрузить чаты';
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  void _setState(ChatsScreenState nextState) {
    if (_isDisposed) return;
    _state = nextState;
    notifyListeners();
  }

  Future<void> loadMoreChats() async {
    if (_state.currentUserId == null) return;
    final cursor = _state.chatsNextCursor;
    if (cursor == null || cursor.isEmpty || _state.chatsLoadingMore) {
      return;
    }

    _setState(_state.copyWith(chatsLoadingMore: true));

    try {
      final page = await _chatsService.getChatsPage(
        currentUserId: _state.currentUserId!,
        limit: 50,
        cursor: cursor,
      );
      final localReads = await _localChatStateService.getAllLastReadMessageIds();

      final byId = {for (final c in _state.allChats) c.id: c};
      for (final c in page.chats) {
        var updated = c;
        final localRead = localReads[c.id];
        if (localRead != null && localRead > updated.myLastReadMessageId) {
          updated = updated.copyWith(myLastReadMessageId: localRead);
        }
        final unreadCount = resolveUnreadCount(
          serverUnreadCount: updated.unreadCount,
          currentUserId: _state.currentUserId,
          lastMessageId: updated.lastMessageId,
          lastMessageSenderId: updated.lastMessageSenderId,
          myLastReadMessageId: updated.myLastReadMessageId,
        );
        if (updated.unreadCount != unreadCount) {
          updated = updated.copyWith(unreadCount: unreadCount);
        }
        byId[c.id] = updated;
      }

      final merged = byId.values.toList();
      merged.sort((a, b) {
        final aMs = serverInstantMillis(a.lastMessageAtRaw) ?? 0;
        final bMs = serverInstantMillis(b.lastMessageAtRaw) ?? 0;
        return bMs.compareTo(aMs);
      });

      _setState(
        _state.copyWith(
          allChats: merged,
          filteredChats: _applySearchToList(merged, _state.searchQuery),
          chatsNextCursor: page.hasMore ? page.nextCursor : null,
          clearChatsNextCursor: !page.hasMore,
          chatsLoadingMore: false,
        ),
      );
    } catch (_) {
      _setState(_state.copyWith(chatsLoadingMore: false));
    }
  }
}
