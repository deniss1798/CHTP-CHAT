import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../core/formatting/server_time.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/notifiers/chats_list_refresh_notifier.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/services/chats_service.dart';
import '../../data/services/chat_socket_service.dart';
import '../../data/services/inbox_socket_service.dart';
import '../../../calls/incoming_call_ringtone.dart';
import '../../../calls/presentation/screens/group_call_screen.dart';
import '../../../calls/presentation/screens/voice_call_screen.dart';
import '../../../calls/voice_call_ring.dart';
import '../../data/services/presence_service.dart';
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

  /// Режим левой колонки на десктопе: открытие чата без полноэкранного push.
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
  final ChatsService _chatsService = ChatsService();
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  List<Map<String, dynamic>> _allChats = [];
  List<Map<String, dynamic>> _filteredChats = [];

  static const Duration _chatsListPollInterval = Duration(seconds: 5);

  Timer? _chatsPollTimer;
  Timer? _presenceTimer;
  Timer? _inboxPingTimer;

  final InboxSocketService _inboxSocket = InboxSocketService();
  StreamSubscription<Map<String, dynamic>>? _inboxSubscription;
  final Map<int, String> _typingLabelByChatId = {};
  final Map<int, Timer> _typingInboxTimers = {};

  late final VoidCallback _chatsRefreshListener;

  @override
  void initState() {
    super.initState();
    _chatsRefreshListener = () {
      if (!mounted || _currentUserId == null) return;
      _loadChats(silent: true);
    };
    chatsListRefreshNotifier.addListener(_chatsRefreshListener);
    WidgetsBinding.instance.addObserver(this);
    _init();
    _searchController.addListener(_applySearch);
    _startChatsPolling();
    _startPresenceHeartbeat();
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceService.ping();
    _presenceTimer = Timer.periodic(const Duration(seconds: 50), (_) {
      _presenceService.ping();
    });
  }

  @override
  void dispose() {
    chatsListRefreshNotifier.removeListener(_chatsRefreshListener);
    _presenceTimer?.cancel();
    _chatsPollTimer?.cancel();
    _inboxPingTimer?.cancel();
    _inboxSubscription?.cancel();
    for (final t in _typingInboxTimers.values) {
      t.cancel();
    }
    _typingInboxTimers.clear();
    _inboxSocket.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _startChatsPolling() {
    _chatsPollTimer?.cancel();
    _chatsPollTimer = Timer.periodic(_chatsListPollInterval, (_) {
      if (!mounted || _currentUserId == null) return;
      _loadChats(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentUserId != null) {
      _loadChats(silent: true);
      if (!_inboxSocket.isConnected) {
        unawaited(_connectInboxWithRetry());
      }
    }
  }

  Future<void> _init() async {
    try {
      final me = await _authService.getMe();
      final rawId = me['id'];

      if (rawId is int) {
        _currentUserId = rawId;
      } else {
        _currentUserId = int.tryParse(rawId.toString());
      }

      await _loadChats();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось инициализировать список чатов';
        _isLoading = false;
      });
    }

    if (_currentUserId != null) {
      await _connectInboxWithRetry();
    }
  }

  void _onInboxMessage(Map<String, dynamic> msg) {
    final t = msg['type']?.toString();
    if (t == 'group_call_invite') {
      unawaited(_handleInboxGroupInvite(msg));
      return;
    }
    if (t == 'call_e2e_init') {
      _handleInboxIncomingCall(msg);
      return;
    }
    if (msg['type'] != 'typing') return;
    final cidRaw = msg['chat_id'];
    int? chatId;
    if (cidRaw is int) {
      chatId = cidRaw;
    } else {
      chatId = int.tryParse(cidRaw?.toString() ?? '');
    }
    if (chatId == null) return;
    final typing = msg['typing'] != false;
    if (!typing) {
      _typingInboxTimers[chatId]?.cancel();
      _typingInboxTimers.remove(chatId);
      if (mounted) {
        setState(() => _typingLabelByChatId.remove(chatId));
      }
      return;
    }
    final uname = (msg['username'] ?? '').toString().trim();
    final isPrivate = _chatTypeById(chatId) == 'private';
    final label = isPrivate
        ? 'Печатает…'
        : (uname.isNotEmpty ? '$uname печатает…' : 'Печатает…');
    _typingInboxTimers[chatId]?.cancel();
    _typingInboxTimers[chatId] = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _typingLabelByChatId.remove(chatId);
        _typingInboxTimers.remove(chatId);
      });
    });
    if (mounted) {
      setState(() => _typingLabelByChatId[chatId!] = label);
    }
  }

  Future<void> _connectInboxWithRetry() async {
    await _inboxSubscription?.cancel();
    _inboxSubscription = null;
    _inboxPingTimer?.cancel();
    _inboxPingTimer = null;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await _inboxSocket.connect(baseHttpUrl: ApiClient.baseUrl);
        _inboxSubscription =
            _inboxSocket.messagesStream.listen(_onInboxMessage);
        _inboxPingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
          if (!_inboxSocket.isConnected) return;
          _inboxSocket.sendPing();
        });
        if (kDebugMode) {
          debugPrint(
            'ChatsScreen: inbox WebSocket connected (${ApiClient.baseUrl})',
          );
        }
        return;
      } catch (e) {
        debugPrint('ChatsScreen: inbox connect attempt ${attempt + 1}/5: $e');
        await Future<void>.delayed(
          Duration(milliseconds: 400 + attempt * 350),
        );
      }
    }
    debugPrint(
      'ChatsScreen: inbox WebSocket failed after retries — '
      'входящие звонки/typing по списку не придут',
    );
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (_currentUserId == null) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final chats = await _chatsService.getChats(
        currentUserId: _currentUserId!,
      );

      if (!mounted) return;

      setState(() {
        _allChats = chats;
        _filteredChats = _applySearchToList(
          chats,
          _searchController.text.trim().toLowerCase(),
        );
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) return;

      String message = 'Не удалось загрузить чаты';

      if (e is DioException) {
        final data = e.response?.data;

        if (data is Map<String, dynamic>) {
          message =
              data['detail']?.toString() ?? data['message']?.toString() ?? message;
        } else if (data is String && data.isNotEmpty) {
          message = data;
        } else if (e.message != null && e.message!.isNotEmpty) {
          message = e.message!;
        }
      } else {
        message = e.toString().replaceFirst('Exception: ', '');
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _applySearchToList(
    List<Map<String, dynamic>> chats,
    String query,
  ) {
    if (query.isEmpty) {
      return List.from(chats);
    }

    return chats.where((chat) {
      final title = _chatTitle(chat).toLowerCase();
      final lastMessage = _lastMessage(chat).toLowerCase();
      return title.contains(query) || lastMessage.contains(query);
    }).toList();
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredChats = _applySearchToList(_allChats, query);
    });
  }

  Future<void> _logout(BuildContext context) async {
    
    await SecureStorageService.deleteAccessToken();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _openChat({
    required int chatId,
    required String title,
    required String chatType,
    String? avatarUrl,
  }) async {
    if (widget.embedded && widget.onChatSelected != null) {
      widget.onChatSelected!(
        chatId: chatId,
        title: title,
        chatType: chatType,
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      await _loadChats(silent: true);
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          title: title,
          chatType: chatType,
          avatarUrl: avatarUrl,
        ),
      ),
    );

    if (!mounted) return;
    await _loadChats(silent: true);
  }

  Future<void> _openCreateChatSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Создать чат',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _CreateChatOption(
                  icon: AppIcons.person,
                  title: 'Личный чат',
                  subtitle: 'Выбрать пользователя по username',
                  onTap: () => Navigator.of(context).pop('private'),
                ),
                const SizedBox(height: 12),
                _CreateChatOption(
                  icon: AppIcons.group,
                  title: 'Групповой чат',
                  subtitle: 'Создать группу с несколькими участниками',
                  onTap: () => Navigator.of(context).pop('group'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    if (result == 'private') {
      final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const UserPickerScreen()),
      );

      await _loadChats();

      if (!mounted || created == null) return;

      final rawChatId = created['chat_id'];
      final chatTitle = (created['chat_title'] ?? 'Чат').toString();

      int? chatId;
      if (rawChatId is int) {
        chatId = rawChatId;
      } else {
        chatId = int.tryParse(rawChatId.toString());
      }

      if (chatId != null) {
        await _openChat(
          chatId: chatId,
          title: chatTitle,
          chatType: 'private',
          avatarUrl: null,
        );
      }
    }

    if (result == 'group') {
      final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const GroupChatCreateScreen()),
      );

      await _loadChats();

      if (!mounted || created == null) return;

      final rawChatId = created['chat_id'];
      final chatTitle = (created['chat_title'] ?? 'Группа').toString();

      int? chatId;
      if (rawChatId is int) {
        chatId = rawChatId;
      } else {
        chatId = int.tryParse(rawChatId.toString());
      }

      if (chatId != null) {
        await _openChat(
          chatId: chatId,
          title: chatTitle,
          chatType: 'group',
          avatarUrl: null,
        );
      }
    }
  }

  String _chatTitle(Map<String, dynamic> chat) {
    final type = (chat['type'] ?? '').toString();

    if (type == 'private') {
      final displayName = (chat['display_name'] ?? '').toString().trim();
      if (displayName.isNotEmpty) {
        return displayName;
      }
    }

    final possible = [
      chat['title'],
      chat['name'],
      chat['chat_name'],
      chat['username'],
      chat['other_user_name'],
      chat['other_username'],
    ];

    for (final value in possible) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    final id = chat['id'] ?? chat['chat_id'];
    return 'Чат ${id ?? ''}'.trim();
  }

  String? _chatAvatarUrl(Map<String, dynamic> chat) {
    final possible = [
      chat['avatar_url'],
      chat['avatarUrl'],
    ];

    for (final value in possible) {
      if (value != null && value.toString().trim().isNotEmpty) {
        final raw = value.toString().trim();

        if (raw.startsWith('http://') || raw.startsWith('https://')) {
          return raw;
        }

        return '${ApiClient.baseUrl}$raw';
      }
    }

    return null;
  }

  String? _chatTypeById(int chatId) {
    for (final c in _allChats) {
      final rawId = c['id'] ?? c['chat_id'];
      int? id;
      if (rawId is int) {
        id = rawId;
      } else {
        id = int.tryParse(rawId?.toString() ?? '');
      }
      if (id == chatId) {
        return (c['type'] ?? '').toString();
      }
    }
    return null;
  }

  String? _titleForChatId(int chatId) {
    for (final c in _allChats) {
      final rawId = c['id'] ?? c['chat_id'];
      int? id;
      if (rawId is int) {
        id = rawId;
      } else {
        id = int.tryParse(rawId?.toString() ?? '');
      }
      if (id == chatId) {
        final t = (c['title'] ?? '').toString().trim();
        return t.isNotEmpty ? t : null;
      }
    }
    return null;
  }

  Future<void> _handleInboxIncomingCall(Map<String, dynamic> msg) async {
    if (kIsWeb) return;
    if (_currentUserId == null) return;
    final cidRaw = msg['chat_id'];
    int? chatId;
    if (cidRaw is int) {
      chatId = cidRaw;
    } else {
      chatId = int.tryParse(cidRaw?.toString() ?? '');
    }
    if (chatId == null) return;
    // Пока список чатов не подгрузился, тип null — не блокируем личный звонок.
    if (_chatTypeById(chatId) == 'group') return;

    final uRaw = msg['user_id'];
    int? callerId;
    if (uRaw is int) {
      callerId = uRaw;
    } else {
      callerId = int.tryParse(uRaw?.toString() ?? '');
    }
    if (callerId == null || callerId == _currentUserId) return;

    final callId = msg['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;
    if (!VoiceCallRing.tryStart(callId)) return;

    final title = _titleForChatId(chatId) ?? 'Чат';
    if (!mounted) return;

    await IncomingCallRingtone.instance.start();
    if (!mounted) {
      await IncomingCallRingtone.instance.stop();
      return;
    }
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Входящий звонок',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            '$title звонит вам',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
                final socket = ChatSocketService();
                try {
                  await socket.connect(
                    chatId: chatId!,
                    baseHttpUrl: ApiClient.baseUrl,
                  );
                  socket.sendJson({
                    'type': 'call_e2e_hangup',
                    'call_id': callId,
                  });
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                } catch (_) {}
                await socket.disconnect();
              },
              child: const Text('Отклонить'),
            ),
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => VoiceCallScreen(
                        chatId: chatId!,
                        peerTitle: title,
                        peerUserId: callerId!,
                        myUserId: _currentUserId!,
                        incomingInit: msg,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Принять'),
            ),
          ],
        ),
      );
    } finally {
      await IncomingCallRingtone.instance.stop();
    }
  }

  Future<void> _handleInboxGroupInvite(Map<String, dynamic> msg) async {
    if (kIsWeb) return;
    if (_currentUserId == null) return;
    final cidRaw = msg['chat_id'];
    int? chatId;
    if (cidRaw is int) {
      chatId = cidRaw;
    } else {
      chatId = int.tryParse(cidRaw?.toString() ?? '');
    }
    if (chatId == null) return;
    // Если список чатов ещё не подгрузился, _chatTypeById может быть null — не отбрасываем инвайт.
    // Инвайт group_call_invite всё равно приходит только из group-чата.
    if (_chatTypeById(chatId) == 'private') return;

    final uRaw = msg['user_id'];
    int? callerId;
    if (uRaw is int) {
      callerId = uRaw;
    } else {
      callerId = int.tryParse(uRaw?.toString() ?? '');
    }
    if (callerId == null || callerId == _currentUserId) return;

    final callId = msg['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;
    if (!VoiceCallRing.tryStart(callId)) return;

    int? startedBy;
    final sb = msg['started_by'];
    if (sb is int) {
      startedBy = sb;
    } else {
      startedBy = int.tryParse(sb?.toString() ?? '') ?? callerId;
    }
    final withVideo = msg['video'] == true;

    final title = _titleForChatId(chatId) ?? 'Чат';
    if (!mounted) return;

    await IncomingCallRingtone.instance.start();
    if (!mounted) {
      await IncomingCallRingtone.instance.stop();
      return;
    }
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Групповой звонок',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Вас зовут в звонок «$title»',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
              },
              child: const Text('Отклонить'),
            ),
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupCallScreen(
                        chatId: chatId!,
                        chatTitle: title,
                        myUserId: _currentUserId!,
                        callId: callId,
                        startedByUserId: startedBy!,
                        memberNames: const <int, String>{},
                        isHost: false,
                        startWithVideo: withVideo,
                        incomingInvite: msg,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Принять'),
            ),
          ],
        ),
      );
    } finally {
      await IncomingCallRingtone.instance.stop();
    }
  }

  String? _previewForLastMessageType(String rawType) {
    final mt = rawType.trim().toLowerCase();
    switch (mt) {
      case 'image':
        return 'Фото';
      case 'video':
        return 'Видео';
      case 'video_note':
        return 'Видеосообщение';
      case 'audio':
        return 'Аудио';
      case 'document':
      case 'file':
        return 'Файл';
      case 'sticker':
        return 'Стикер';
      case 'text':
        return null;
      default:
        return 'Медиа';
    }
  }

  String _lastMessage(Map<String, dynamic> chat) {
    final possible = [
      chat['last_message'],
      chat['lastMessage'],
      chat['message'],
      chat['last_message_text'],
      chat['content'],
    ];

    for (final value in possible) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    final mt = (chat['last_message_type'] ?? chat['lastMessageType'])
        ?.toString()
        .trim();
    if (mt != null && mt.isNotEmpty) {
      final preview = _previewForLastMessageType(mt);
      if (preview != null) {
        return preview;
      }
    }

    return chat['type'] == 'private' ? 'Личный чат' : 'Групповой чат';
  }

  String _timeText(Map<String, dynamic> chat) {
    final possible = [
      chat['last_message_at'],
      chat['updated_at'],
      chat['created_at'],
    ];

    for (final value in possible) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return _formatShortTime(value.toString());
      }
    }

    return '';
  }

  String _formatShortTime(String raw) {
    final local = parseServerUtcInstant(raw)?.toLocal();
    if (local == null) return raw;

    final now = DateTime.now();

    final sameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;

    if (sameDay) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  int? _intFromChatField(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  int _parseUnreadRaw(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// Счётчик с сервера; если 0 — эвристика по last_message_id vs my_last_read (последнее от собеседника).
  int _unreadCount(Map<String, dynamic> chat) {
    final api = _parseUnreadRaw(chat['unread_count'] ?? chat['unreadCount']);
    if (api > 0) return api;

    if (_currentUserId == null) return 0;

    final lastId = _intFromChatField(
      chat['last_message_id'] ?? chat['lastMessageId'],
    );
    final lastSender = _intFromChatField(
      chat['last_message_sender_id'] ?? chat['lastMessageSenderId'],
    );
    final myRead = _intFromChatField(
          chat['my_last_read_message_id'] ?? chat['myLastReadMessageId'],
        ) ??
        0;

    if (lastId == null || lastSender == null) return 0;
    if (lastSender == _currentUserId) return 0;
    if (lastId > myRead) return 1;
    return 0;
  }

  static const Duration _peerOnlineThreshold = Duration(seconds: 180);

  bool _peerOnlineFromLastSeenRaw(dynamic raw) {
    if (raw == null) return false;
    final t = parseServerUtcInstant(raw.toString());
    if (t == null) return false;
    return DateTime.now().toUtc().difference(t) <= _peerOnlineThreshold;
  }

  bool _peerOnlineInList(Map<String, dynamic> chat) {
    if ((chat['type'] ?? '').toString() != 'private') return false;
    return _peerOnlineFromLastSeenRaw(chat['peer_last_seen_at']);
  }

  String _initials(String title) {
    final parts =
        title.split(' ').where((e) => e.trim().isNotEmpty).take(2).toList();

    if (parts.isEmpty) return 'Ч';

    if (parts.length == 1) {
      final word = parts.first.trim();
      return word.isNotEmpty ? word[0].toUpperCase() : 'Ч';
    }

    final first = parts[0].trim();
    final second = parts[1].trim();

    final firstChar = first.isNotEmpty ? first[0].toUpperCase() : '';
    final secondChar = second.isNotEmpty ? second[0].toUpperCase() : '';

    final result = '$firstChar$secondChar'.trim();
    return result.isEmpty ? 'Ч' : result;
  }

  Widget _buildChatAvatar({
    required String title,
    required String? avatarUrl,
    double size = 52,
    bool showOnlineDot = false,
  }) {
    final safeUrl = (avatarUrl ?? '').trim();

    Widget inner;

    if (safeUrl.isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          safeUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(title),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
      );
    } else {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          _initials(title),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (!showOnlineDot) return inner;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        inner,
        Positioned(
          right: 0,
          bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
        ),
      ],
    );
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
                onPressed: _loadChats,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredChats.isEmpty) {
      return const Center(
        child: Text(
          'Чаты не найдены',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadChats,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          widget.embedded ? 12 : 20,
          0,
          widget.embedded ? 12 : 20,
          widget.embedded ? 96 : 110,
        ),
        itemCount: _filteredChats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final chat = _filteredChats[index];
          final title = _chatTitle(chat);
          final avatarUrl = _chatAvatarUrl(chat);
          final unreadCount = _unreadCount(chat);
          final lastMessage = _lastMessage(chat);
          final timeText = _timeText(chat);

          final rawId = chat['id'] ?? chat['chat_id'];
          int? chatId;

          if (rawId is int) {
            chatId = rawId;
          } else {
            chatId = int.tryParse(rawId.toString());
          }

          final typingLabel =
              chatId != null ? _typingLabelByChatId[chatId] : null;

          final isUnread = unreadCount > 0;
          final isSelected =
              widget.selectedChatId != null && chatId == widget.selectedChatId;

          return GestureDetector(
            onTap: chatId == null
                ? null
                : () => _openChat(
                      chatId: chatId!,
                      title: title,
                      chatType: (chat['type'] ?? '').toString(),
                      avatarUrl: avatarUrl,
                    ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withAlpha(22)
                      : (isUnread
                          ? AppColors.accent.withAlpha(10)
                          : AppColors.surface),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent.withAlpha(160)
                        : Colors.white.withAlpha(isUnread ? 10 : 8),
                    width: 1,
                  ),
                  boxShadow: AppShadows.lift,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isUnread)
                        Container(
                          width: 4,
                          color: AppColors.accent,
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChatAvatar(
                    title: title,
                    avatarUrl: avatarUrl,
                    size: 52,
                    showOnlineDot: _peerOnlineInList(chat),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight:
                                  isUnread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            typingLabel ?? lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: typingLabel != null
                                  ? AppColors.accent
                                  : (isUnread
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary),
                              fontSize: 14,
                              fontStyle: typingLabel != null
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: TextStyle(
                            color: isUnread
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: AppShadows.primaryButton,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'ЧТП',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withAlpha(10),
                                foregroundColor: AppColors.textPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                              ),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );

                                if (!mounted) return;
                                await _loadChats(silent: true);
                              },
                              icon: const Icon(AppIcons.settings),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withAlpha(10),
                                foregroundColor: AppColors.textPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                              ),
                              onPressed: () => _logout(context),
                              icon: const Icon(AppIcons.logout),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Сообщения',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_allChats.length} чатов',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Поиск по чатам',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                            ),
                            filled: true,
                            fillColor: AppColors.inputFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(20),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 1.2,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(20),
                              ),
                            ),
                            prefixIcon: const Icon(
                              AppIcons.search,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: _buildBody(),
                  ),
                ],
              ),
              Positioned(
                right: widget.embedded ? 12 : 20,
                bottom: widget.embedded ? 16 : 20,
                child: GestureDetector(
                  onTap: _openCreateChatSheet,
                  child: Container(
                    width: AppSizes.fab,
                    height: AppSizes.fab,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.accentFab(),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      AppIcons.add,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateChatOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateChatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.white.withAlpha(10)),
          boxShadow: AppShadows.lift,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: AppShadows.primaryButton,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.black,
                size: AppSizes.iconMd,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              AppIcons.chevronRight,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}