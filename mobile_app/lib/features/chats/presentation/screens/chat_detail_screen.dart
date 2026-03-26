import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/chat_socket_service.dart';
import '../../data/services/local_chat_state_service.dart';
import '../../data/services/messages_service.dart';
import 'chat_member_add_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final int chatId;
  final String title;
  final String chatType;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.chatType,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final AuthService _authService = AuthService();
  final MessagesService _messagesService = MessagesService();
  final ChatSocketService _chatSocketService = ChatSocketService();
  final LocalChatStateService _localChatStateService = LocalChatStateService();
  final Dio _dio = ApiClient.dio;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isSocketConnected = false;
  String? _error;

  int? _currentUserId;
  List<Map<String, dynamic>> _messages = [];
  final Map<int, String> _memberNames = {};

  bool get _isGroupChat => widget.chatType == 'group';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _chatSocketService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final me = await _authService.getMe();
      final userId = me['id'];

      if (userId is int) {
        _currentUserId = userId;
      } else {
        _currentUserId = int.tryParse(userId.toString());
      }

      if (_isGroupChat) {
        await _loadChatMembers();
      }

      await _loadMessages();
      await _connectSocket();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _extractErrorMessage(e, fallback: 'Не удалось открыть чат');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChatMembers() async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    Future<void> _openAddMemberScreen() async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ChatMemberAddScreen(
        chatId: widget.chatId,
        existingMemberIds: _memberNames.keys.toSet(),
      ),
    ),
  );

  if (!mounted || result != true) return;

  try {
    await _loadChatMembers();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Участник успешно добавлен'),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceSoft,
        content: Text(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось обновить список участников',
          ),
        ),
      ),
    );
  }
}

    final response = await _dio.get(
      '/chats/${widget.chatId}/members',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data;

    if (data is List) {
      _memberNames.clear();

      for (final item in data) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final rawId = map['id'];
          final username = (map['username'] ?? '').toString().trim();

          int? userId;
          if (rawId is int) {
            userId = rawId;
          } else {
            userId = int.tryParse(rawId.toString());
          }

          if (userId != null && username.isNotEmpty) {
            _memberNames[userId] = username;
          }
        }
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _messagesService.getMessages(widget.chatId);

      messages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;

        return aDate.compareTo(bDate);
      });

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(jump: true);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _extractErrorMessage(
          e,
          fallback: 'Не удалось загрузить сообщения',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _connectSocket() async {
    await _socketSubscription?.cancel();

    try {
      await _chatSocketService.connect(
        chatId: widget.chatId,
        baseHttpUrl: ApiClient.baseUrl,
      );

      _socketSubscription = _chatSocketService.messagesStream.listen((message) {
        _handleIncomingMessage(message);
      });

      if (!mounted) return;

      setState(() {
        _isSocketConnected = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSocketConnected = false;
      });
    }
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> incoming) async {
    final normalized = _extractMessagePayload(incoming);
    if (normalized == null) return;

    final incomingId = normalized['id'];
    final exists = _messages.any((m) => m['id'] == incomingId);

    if (exists) return;
    if (!mounted) return;

    setState(() {
      _messages.add(normalized);
      _messages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;

        return aDate.compareTo(bDate);
      });
    });

    await _markCurrentChatAsRead();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Map<String, dynamic>? _extractMessagePayload(Map<String, dynamic> raw) {
    if (raw.containsKey('chat_id') &&
        raw.containsKey('sender_id') &&
        raw.containsKey('text')) {
      return raw;
    }

    final message = raw['message'];
    if (message is Map<String, dynamic>) return message;
    if (message is Map) return Map<String, dynamic>.from(message);

    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    return null;
  }

  Future<void> _markCurrentChatAsRead() async {
    if (_messages.isEmpty) return;

    final lastMessage = _messages.last;
    final rawId = lastMessage['id'];

    int? lastMessageId;
    if (rawId is int) {
      lastMessageId = rawId;
    } else {
      lastMessageId = int.tryParse(rawId.toString());
    }

    await _localChatStateService.markChatAsRead(
      chatId: widget.chatId,
      lastMessageId: lastMessageId,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final createdMessage = await _messagesService.sendMessage(
        chatId: widget.chatId,
        text: text,
      );

      if (!mounted) return;

      _messageController.clear();

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
        _isSending = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            _extractErrorMessage(e, fallback: 'Не удалось отправить сообщение'),
          ),
        ),
      );
    }
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.position.maxScrollExtent + 120;

    if (jump) {
      _scrollController.jumpTo(offset);
      return;
    }

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _extractErrorMessage(Object e, {required String fallback}) {
    if (e is DioException) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        return data['detail']?.toString() ??
            data['message']?.toString() ??
            fallback;
      }

      if (data is String && data.isNotEmpty) {
        return data;
      }

      if (e.message != null && e.message!.isNotEmpty) {
        return e.message!;
      }
    }

    return e.toString().replaceFirst('Exception: ', '');
  }

  bool _isMine(Map<String, dynamic> message) {
    final senderId = message['sender_id'];

    if (_currentUserId == null || senderId == null) return false;

    if (senderId is int) return senderId == _currentUserId;
    return int.tryParse(senderId.toString()) == _currentUserId;
  }

  String _senderName(Map<String, dynamic> message) {
    final rawSenderId = message['sender_id'];

    int? senderId;
    if (rawSenderId is int) {
      senderId = rawSenderId;
    } else {
      senderId = int.tryParse(rawSenderId.toString());
    }

    if (senderId == null) return 'Пользователь';

    if (senderId == _currentUserId) {
      return 'Вы';
    }

    return _memberNames[senderId] ?? 'Пользователь';
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';

    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDateLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';

    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day.$month.$year';
  }

  bool _shouldShowDateDivider(int index) {
    final current = _formatDateLabel(_messages[index]['created_at']?.toString());
    if (current.isEmpty) return false;

    if (index == 0) return true;

    final previous =
        _formatDateLabel(_messages[index - 1]['created_at']?.toString());

    return current != previous;
  }

  Widget _buildDateDivider(String label) {
    if (label.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentBorder.withAlpha(80)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = _isMine(message);
    final text = (message['text'] ?? '').toString();
    final time = _formatTime(message['created_at']?.toString());
    final isUpdated = message['is_updated'] == true;
    final senderName = _senderName(message);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMine ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 8),
            bottomRight: Radius.circular(isMine ? 8 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: isMine
                  ? AppColors.accent.withAlpha(28)
                  : Colors.black.withAlpha(18),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (_isGroupChat && !isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Text(
              text,
              style: TextStyle(
                color: isMine ? Colors.black : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUpdated)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      'изменено',
                      style: TextStyle(
                        color: isMine
                            ? Colors.black.withAlpha(160)
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  time,
                  style: TextStyle(
                    color: isMine
                        ? Colors.black.withAlpha(170)
                        : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Сообщений пока нет',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final children = <Widget>[];

          if (_shouldShowDateDivider(index)) {
            final label =
                _formatDateLabel(message['created_at']?.toString());

            if (label.isNotEmpty) {
              children.add(_buildDateDivider(label));
            }
          }

          children.add(_buildMessageBubble(message));

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(235),
          border: Border(
            top: BorderSide(
              color: AppColors.accentBorder.withAlpha(100),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: AppColors.textPrimary),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withAlpha(55),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isSocketConnected
            ? Colors.green.withAlpha(30)
            : Colors.red.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _isSocketConnected ? 'online' : 'offline',
        style: TextStyle(
          color: _isSocketConnected ? Colors.greenAccent : Colors.redAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
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
                onPressed: _initChat,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildMessagesList()),
        _buildInputBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0B0D),
              Color(0xFF09090B),
              Color(0xFF140A02),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(185),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.accentBorder.withAlpha(90),
                    ),
                  ),
                ),
     child: Row(
  children: [
    IconButton(
      onPressed: () => Navigator.of(context).pop(true),
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.textPrimary,
      ),
    ),
    Expanded(
      child: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    if (_isGroupChat)
      IconButton(
        tooltip: 'Добавить участника',
        onPressed: _openAddMemberScreen,
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
          color: AppColors.accent,
        ),
      ),
    _buildConnectionBadge(),
  ],
),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}