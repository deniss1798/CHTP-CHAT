import 'dart:async';
import 'dart:io' show File;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../core/constants/document_attachments.dart';
import '../../../../core/formatting/last_seen_label.dart';
import '../../../../core/formatting/server_time.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/notifiers/open_chat_state_notifier.dart';
import '../../../../core/push/local_notifications_service.dart';
import '../../../../core/realtime/chat_ws_contract.dart';
import '../../../../core/platform/desktop_layout.dart';
import '../../../../core/notifiers/chats_list_refresh_notifier.dart';
import '../../../../core/notifiers/open_chat_sync_notifier.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../calls/incoming_call_ringtone.dart';
import '../../../calls/presentation/screens/group_call_screen.dart';
import '../../../calls/presentation/screens/voice_call_screen.dart';
import '../../../calls/voice_call_ring.dart';
import '../../data/services/chat_socket_service.dart';
import '../../data/services/local_chat_state_service.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/messages_service.dart';
import '../../data/services/presence_service.dart';
import 'attachment_preview_screen.dart';
import 'chat_member_add_screen.dart';
import 'video_note_record_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../data/services/chat_avatar_service.dart';
import '../../data/services/chats_service.dart';
import 'group_members_manage_screen.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../chat_detail_formatters.dart';
import '../chat_detail_message_maps.dart';
import '../controllers/chat_detail_controller.dart';
import '../widgets/chat_detail_app_bar.dart';
import '../widgets/chat_detail_avatar_widgets.dart';
import '../widgets/chat_composer_action_sheet.dart';
import '../widgets/chat_detail_conversation_view.dart';
import '../widgets/chat_detail_fullscreen_image_viewer.dart';
import '../widgets/chat_detail_fullscreen_video_page.dart';
import '../widgets/chat_detail_message_content.dart' show PollVoteBus;
import '../widgets/chat_pinned_messages_banner.dart';
import '../widgets/messenger_styled_dialogs.dart';
import '../widgets/chat_message_actions_panel.dart';
import '../widgets/poll_create_sheet.dart';

part 'chat_detail_screen_logic.dart';
part 'chat_detail_screen_lifecycle.dart';
part 'chat_detail_screen_realtime.dart';
part 'chat_detail_screen_composer.dart';

class ChatDetailScreen extends StatefulWidget {
  final int chatId;
  final String title;
  final String chatType;
  final String? avatarUrl;

  /// На десктопе в двухпанельном режиме вместо [Navigator.pop].
  final VoidCallback? onBackOverride;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.chatType,
    this.avatarUrl,
    this.onBackOverride,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

abstract class _ChatDetailScreenStateBase extends State<ChatDetailScreen> {
  final AuthService _authService = AuthService();
  final MessagesService _messagesService = MessagesService();
  final ChatSocketService _chatSocketService = ChatSocketService();
  final LocalChatStateService _localChatStateService = LocalChatStateService();
  final ChatAvatarService _chatAvatarService = ChatAvatarService();
  final ChatsService _chatsService = ChatsService();
  final ImagePicker _imagePicker = ImagePicker();
  final PresenceService _presenceService = PresenceService();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final MessageListController _messageListController = MessageListController();
  final MessageSendController _messageSendController = MessageSendController();
  final ComposerController _composerController = ComposerController();
  final MediaUploadController _mediaUploadController = MediaUploadController();
  final ChatSocketController _chatSocketController = ChatSocketController();
  final ChatSocketEventController _chatSocketEventController =
      ChatSocketEventController();
  final MessageActionController _messageActionController = MessageActionController();

  bool _recordingVoice = false;
  bool _isUploadingChatAvatar = false;
  bool _isSendingImage = false;
  bool _isSendingVideo = false;
  bool _isSendingDocument = false;
  bool _isSendingVoice = false;
  bool _hasMoreMessages = true;
  bool _isLoadingOlder = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isRecoveringRealtime = false;
  bool _isDrainingOutbox = false;
  String? _error;

  int? _currentUserId;
  List<Map<String, dynamic>> _messages = [];

  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingMessage;
  List<Map<String, dynamic>> _pinnedMessages = const [];
  int _pinnedCarouselIndex = 0;

  String _chatTitle = '';
  String? _chatAvatarUrl;
  int? _groupCreatedBy;

  final Map<int, String> _memberNames = {};
  final Map<int, String?> _memberAvatarUrls = {};
  final Map<int, DateTime?> _memberLastSeen = {};

  Timer? _presenceTimer;
  Timer? _socketReconnectTimer;
  Timer? _socketPingTimer;
  Timer? _outboxRetryTimer;
  /// Обновление подписи «N мин/ч назад» в шапке личного чата.
  Timer? _lastSeenSubtitleTimer;

  static const Duration _peerOnlineThreshold = Duration(seconds: 180);

  /// user_id -> last_read_message_id (с сервера)
  final Map<int, int> _lastReadByUserId = {};

  Timer? _typingDebounce;
  /// Отправка `typing: false` после паузы в собственном вводе.
  Timer? _localTypingStopTimer;
  /// Скрыть строку «… печатает» после тишины от собеседника.
  Timer? _remoteTypingHideTimer;
  int? _typingUserId;

  bool get _isGroupChat => widget.chatType == 'group';

  bool _isPeerOnlineFromLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return false;
    final now = DateTime.now().toUtc();
    final t = lastSeen.toUtc();
    return now.difference(t) <= _peerOnlineThreshold;
  }
}

class _ChatDetailScreenState extends _ChatDetailScreenStateBase
    with
        _ChatDetailStateHelpers,
        _ChatDetailRealtimeAndCallsLogic,
        _ChatDetailLifecycleLogic,
        _ChatDetailComposerAndActionsLogic {
  @override
  void initState() {
    super.initState();
    _chatTitle = widget.title;
    _chatAvatarUrl = widget.avatarUrl;
    markChatOpen(widget.chatId);
    if (LocalNotificationsService.supported) {
      unawaited(
        LocalNotificationsService.instance.cancelChatNotification(widget.chatId),
      );
    }
    _messageController.addListener(_onMessageTextChanged);
    _scrollController.addListener(_onMessagesScroll);
    if (!_isGroupChat) {
      _lastSeenSubtitleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
    _initChat();
    openChatSyncNotifier.addListener(_onOpenChatSyncRequest);
    PollVoteBus.setHandler((msgId, optId, multi) {
      unawaited(_votePoll(msgId, optId, multi));
    });
  }

  @override
  void dispose() {
    PollVoteBus.setHandler(null);
    clearOpenChat(widget.chatId);
    openChatSyncNotifier.removeListener(_onOpenChatSyncRequest);
    _socketReconnectTimer?.cancel();
    _socketPingTimer?.cancel();
    _outboxRetryTimer?.cancel();
    _lastSeenSubtitleTimer?.cancel();
    _presenceTimer?.cancel();
    _typingDebounce?.cancel();
    _localTypingStopTimer?.cancel();
    _remoteTypingHideTimer?.cancel();
    _messageController.removeListener(_onMessageTextChanged);
    _scrollController.removeListener(_onMessagesScroll);
    _socketSubscription?.cancel();
    _chatSocketService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    unawaited(_voiceRecorder.dispose());
    super.dispose();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initChat,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final reply = _replyingTo;
    final typingLabel = _typingUserId == null
        ? null
        : (_isGroupChat
            ? '${_senderNameForUserId(_typingUserId)} печатает…'
            : 'Печатает…');

    final mentionSuggestions = _isGroupChat
        ? _computeMentionSuggestions(_messageController.text,
            _messageController.selection.extentOffset)
        : const <int>[];
    final mentionWidget = mentionSuggestions.isEmpty
        ? const SizedBox.shrink()
        : Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.18),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: mentionSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (_, i) {
                  final uid = mentionSuggestions[i];
                  final name = _memberNames[uid] ?? 'Участник $uid';
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      '@$name',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    onTap: () => _applyMentionSuggestion(uid),
                  );
                },
              ),
            ),
          );

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        ChatDetailConversationView(
          messages: _messages,
          scrollController: _scrollController,
          isGroupChat: _isGroupChat,
      currentUserId: _currentUserId,
      memberNames: _memberNames,
      memberAvatarUrls: _memberAvatarUrls,
      lastReadByUserId: _lastReadByUserId,
      onRefresh: _loadMessages,
      onSwipeReply: (m) {
        setState(() {
          _replyingTo = Map<String, dynamic>.from(m);
          _editingMessage = null;
        });
      },
      onMessageActions: _showMessageActions,
      onOpenFullscreenImage: _openFullscreenImage,
      onOpenFullscreenVideo: _openFullscreenVideo,
      onOpenSenderProfile: (userId) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UserProfileScreen(userId: userId),
          ),
        );
      },
      onReactionEmojiTap: _toggleReactionEmoji,
      typingLabel: typingLabel,
      messageController: _messageController,
      isEditing: _editingMessage != null,
      replyingTo: reply,
      replyAuthorLabel: reply != null ? _senderName(reply) : '',
      isSending: _isSending,
      isSendingImage: _isSendingImage,
      isSendingVideo: _isSendingVideo,
      isSendingDocument: _isSendingDocument,
      isSendingVoice: _isSendingVoice,
      isRecordingVoice: _recordingVoice,
      onCancelEdit: _cancelEdit,
      onCancelReply: _cancelReply,
      onPickAttachment: _showAttachmentPicker,
      onVideoNote: _openVideoNoteRecorder,
      onVoiceRecordTap: _toggleVoiceRecording,
      onVoicePickFile: _pickAndSendVoiceFile,
      onSend: _sendMessage,
      onDesktopExtras: _showDesktopComposerExtras,
      onDesktopDocumentsDropped: _onDesktopDocumentsDropped,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 78,
          child: mentionWidget,
        ),
      ],
    );
  }

  List<int> _computeMentionSuggestions(String text, int cursor) {
    if (!_isGroupChat) return const [];
    if (text.isEmpty || cursor <= 0) return const [];
    final clampedCursor = cursor.clamp(0, text.length);
    final before = text.substring(0, clampedCursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return const [];
    if (at > 0) {
      final prev = before[at - 1];
      if (RegExp(r'[A-Za-z0-9_]').hasMatch(prev)) return const [];
    }
    final fragment = before.substring(at + 1);
    if (fragment.contains(' ') || fragment.contains('\n')) return const [];
    final query = fragment.toLowerCase();
    final ids = <int>[];
    for (final entry in _memberNames.entries) {
      if (entry.key == _currentUserId) continue;
      final name = entry.value.trim();
      if (name.isEmpty) continue;
      if (query.isEmpty || name.toLowerCase().startsWith(query)) {
        ids.add(entry.key);
      }
    }
    ids.sort((a, b) =>
        (_memberNames[a] ?? '').compareTo(_memberNames[b] ?? ''));
    return ids.take(6).toList();
  }

  void _applyMentionSuggestion(int userId) {
    final name = (_memberNames[userId] ?? '').trim();
    if (name.isEmpty) return;
    final text = _messageController.text;
    final cursor = _messageController.selection.extentOffset.clamp(
      0,
      text.length,
    );
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return;
    final insertion = '@$name ';
    final next = before.substring(0, at) + insertion + after;
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + insertion.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visibleTitle = _chatTitle.trim().isNotEmpty ? _chatTitle : widget.title;
    final peerId = _privatePeerUserId();
    final peerOnline = !_isGroupChat &&
        peerId != null &&
        _isPeerOnlineFromLastSeen(_memberLastSeen[peerId]);
    final peerSubtitle = !_isGroupChat
        ? (peerOnline
            ? 'в сети'
            : 'был(а) в сети ${LastSeenLabel.formatOffline(
                peerId != null ? _memberLastSeen[peerId] : null,
              )}')
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        showAmbientGlow: false,
        child: SafeArea(
          child: Column(
            children: [
              ChatDetailAppBar(
                visibleTitle: visibleTitle,
                isGroupChat: _isGroupChat,
                peerOnline: peerOnline,
                peerSubtitle: peerSubtitle,
                onBack: () {
                  if (widget.onBackOverride != null) {
                    widget.onBackOverride!();
                  } else {
                    Navigator.of(context).pop(true);
                  }
                },
                avatarLeading: GestureDetector(
                  onTap: () {
                    if (!_isGroupChat) {
                      final pid = _privatePeerUserId();
                      if (pid != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: pid,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: ChatDetailSquareAvatar(
                    title: visibleTitle,
                    avatarUrl: _chatAvatarUrl,
                    size: 42,
                    showOnlineDot: false,
                  ),
                ),
                onVoiceCall: _startVoiceCall,
                onGroupCall: _startGroupCall,
                onPickGroupAvatar: _pickAndUploadChatAvatar,
                isUploadingChatAvatar: _isUploadingChatAvatar,
                onAddMember: _openAddMemberScreen,
                onMenuSelected: (value) {
                  if (value == 'rename') {
                    unawaited(_showRenameGroupDialog());
                  } else if (value == 'members') {
                    unawaited(_openGroupMembersManage());
                  } else if (value == 'leave') {
                    unawaited(_leaveGroup());
                  }
                },
                menuShowMembersItem: _isGroupChat,
                onSearchInChat: isDesktopMessengerLayout ? _showInChatSearch : null,
                onVideoCall: isDesktopMessengerLayout && !_isGroupChat
                    ? _startVoiceCall
                    : null,
                onMorePrivate: isDesktopMessengerLayout && !_isGroupChat
                    ? _showPrivateChatHeaderMenu
                    : null,
              ),
              if (_pinnedMessages.isNotEmpty)
                ChatPinnedMessagesBanner(
                  messages: _pinnedMessages,
                  currentIndex: _pinnedCarouselIndex,
                  onTap: () {
                    final m = _pinnedMessages[_pinnedCarouselIndex.clamp(
                      0,
                      _pinnedMessages.length - 1,
                    )];
                    final id =
                        ChatDetailMessageMaps.intFromDynamic(m['id']);
                    if (id != null) {
                      _scrollToMessageById(id);
                    }
                  },
                  onCycle: () {
                    setState(() {
                      _pinnedCarouselIndex =
                          (_pinnedCarouselIndex + 1) %
                              _pinnedMessages.length;
                    });
                  },
                  onUnpin: () {
                    final m = _pinnedMessages[_pinnedCarouselIndex.clamp(
                      0,
                      _pinnedMessages.length - 1,
                    )];
                    final id =
                        ChatDetailMessageMaps.intFromDynamic(m['id']);
                    if (id != null) {
                      unawaited(_togglePin(id, pin: false));
                    }
                  },
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}
