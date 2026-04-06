import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/chat_socket_service.dart';
import '../../data/services/local_chat_state_service.dart';
import '../../data/services/messages_service.dart';
import 'chat_member_add_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../data/services/chat_avatar_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final int chatId;
  final String title;
  final String chatType;
  final String? avatarUrl;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.chatType,
    this.avatarUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _VideoMessageWidget extends StatefulWidget {
  final String url;
  final bool isMine;

  const _VideoMessageWidget({
    required this.url,
    required this.isMine,
  });

  @override
  State<_VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<_VideoMessageWidget> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
      });
    });

    _controller.addListener(() {
      if (!mounted) return;
      final playing = _controller.value.isPlaying;
      if (playing) {
        if (_showOverlay) setState(() => _showOverlay = false);
      } else {
        if (!_showOverlay) setState(() => _showOverlay = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_initialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isMine ? Colors.black.withAlpha(20) : AppColors.surfaceSoft;

    if (!_initialized) {
      return Container(
        color: bg,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          AnimatedOpacity(
            opacity: _showOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(55),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(
                _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final AuthService _authService = AuthService();
  final MessagesService _messagesService = MessagesService();
  final ChatSocketService _chatSocketService = ChatSocketService();
  final LocalChatStateService _localChatStateService = LocalChatStateService();
  final Dio _dio = ApiClient.dio;
  final ChatAvatarService _chatAvatarService = ChatAvatarService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isUploadingChatAvatar = false;
  bool _isSendingImage = false;
  bool _isSendingVideo = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isSocketConnected = false;
  String? _error;

  int? _currentUserId;
  List<Map<String, dynamic>> _messages = [];

  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingMessage;

  String _chatTitle = '';
  String? _chatAvatarUrl;

  final Map<int, String> _memberNames = {};
  final Map<int, String?> _memberAvatarUrls = {};

  bool get _isGroupChat => widget.chatType == 'group';

  @override
  void initState() {
    super.initState();
    _chatTitle = widget.title;
    _chatAvatarUrl = widget.avatarUrl;
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

Future<void> _pickAndUploadChatAvatar() async {
  if (!_isGroupChat || _isUploadingChatAvatar) return;

  final picked = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1600,
  );

  if (picked == null) return;

  setState(() {
    _isUploadingChatAvatar = true;
  });

  try {
    final updated = await _chatAvatarService.uploadChatAvatar(
      chatId: widget.chatId,
      file: File(picked.path),
    );

    final rawAvatar = (updated['avatar_url'] ?? '').toString().trim();

    if (!mounted) return;

   setState(() {
  _chatAvatarUrl = rawAvatar.isNotEmpty ? rawAvatar : null;
  _isUploadingChatAvatar = false;
});

await _loadChatDetails();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Аватар группы обновлен'),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isUploadingChatAvatar = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _extractErrorMessage(
            e,
            fallback: 'Не удалось обновить аватар группы',
          ),
        ),
      ),
    );
  }
}

  String _buildInitials(String title) {
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

  String? _normalizedAvatarUrl(String? avatarUrl) {
    final raw = (avatarUrl ?? '').trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return '${ApiClient.baseUrl}$raw';
  }

  Widget _buildSquareAvatar({
    required String title,
    required String? avatarUrl,
    double size = 42,
  }) {
    final safeUrl = _normalizedAvatarUrl(avatarUrl);

    if (safeUrl != null && safeUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                _buildInitials(title),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        _buildInitials(title),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCircleAvatar({
    required String title,
    required String? avatarUrl,
    double size = 34,
  }) {
    final safeUrl = _normalizedAvatarUrl(avatarUrl);

    if (safeUrl != null && safeUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          safeUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _buildInitials(title),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _buildInitials(title),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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

      await _loadChatDetails();

      await _loadChatMembers();

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

  Future<void> _loadChatDetails() async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final response = await _dio.get(
      '/chats/${widget.chatId}',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data;

    Map<String, dynamic>? map;

    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    }

    if (map == null) return;

    final title = (map['title'] ?? '').toString().trim();
    final avatarUrl = (map['avatar_url'] ?? '').toString().trim();

    if (!mounted) return;

    setState(() {
      if (title.isNotEmpty) {
        _chatTitle = title;
      }
      _chatAvatarUrl = avatarUrl.isNotEmpty ? avatarUrl : null;
    });
  }

  Future<void> _loadChatMembers() async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
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
      _memberAvatarUrls.clear();

      for (final item in data) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final rawId = map['id'];
          final username = (map['username'] ?? '').toString().trim();
          final rawAvatar = (map['avatar_url'] ?? '').toString().trim();

          int? userId;
          if (rawId is int) {
            userId = rawId;
          } else {
            userId = int.tryParse(rawId.toString());
          }

          if (userId != null) {
            if (username.isNotEmpty) {
              _memberNames[userId] = username;
            }
            _memberAvatarUrls[userId] = rawAvatar.isNotEmpty ? rawAvatar : null;
          }
        }
      }
    }
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
      await _loadChatDetails();

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

  Future<void> _loadMessages() async {
    try {
      final messages = await _messagesService.getMessages(widget.chatId);
      final normalizedMessages = messages.map(_normalizeMessageMap).toList();

      normalizedMessages.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;

        return aDate.compareTo(bDate);
      });

      if (!mounted) return;

      setState(() {
        _messages = normalizedMessages;
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
        _handleSocketEvent(message);
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

  void _handleSocketEvent(Map<String, dynamic> incoming) {
    if (incoming['event'] == 'message_deleted') {
      final rawId = incoming['id'];
      int? id;
      if (rawId is int) {
        id = rawId;
      } else {
        id = int.tryParse(rawId.toString());
      }

      if (id == null) return;

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m['id'] == id);
        if (_editingMessage != null && _editingMessage!['id'] == id) {
          _editingMessage = null;
          _messageController.clear();
        }
      });

      return;
    }

    if (incoming['event'] == 'message_updated') {
      final msg = incoming['message'];
      if (msg is! Map) return;

      final normalized =
          _normalizeMessageMap(Map<String, dynamic>.from(msg));
      final incomingId = normalized['id'];

      if (!mounted) return;

      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == incomingId);
        if (idx >= 0) {
          _messages[idx] = normalized;
        }
      });

      return;
    }

    if (incoming['type'] == 'new_message' || incoming.containsKey('message')) {
      _handleNewMessage(incoming);
    }
  }

  Future<void> _handleNewMessage(Map<String, dynamic> incoming) async {
    final payload = _extractMessagePayload(incoming);
    if (payload == null) return;

    final normalized = _normalizeMessageMap(payload);
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
      return Map<String, dynamic>.from(raw);
    }

    final message = raw['message'];
    if (message is Map<String, dynamic>) return message;
    if (message is Map) return Map<String, dynamic>.from(message);

    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    return null;
  }

  Map<String, dynamic> _normalizeMessageMap(Map<String, dynamic> raw) {
    Map<String, dynamic>? replyTo;
    final rt = raw['reply_to'];
    if (rt is Map<String, dynamic>) {
      replyTo = rt;
    } else if (rt is Map) {
      replyTo = Map<String, dynamic>.from(rt);
    }

    int? replyToId;
    final rawReplyId = raw['reply_to_message_id'];
    if (rawReplyId is int) {
      replyToId = rawReplyId;
    } else if (rawReplyId != null) {
      replyToId = int.tryParse(rawReplyId.toString());
    }

    return {
      'id': raw['id'],
      'chat_id': raw['chat_id'],
      'sender_id': raw['sender_id'],
      'text': (raw['text'] ?? '').toString(),
      'message_type': (raw['message_type'] ?? 'text').toString(),
      'media_key': raw['media_key']?.toString(),
      'media_url': raw['media_url']?.toString(),
      'media_mime_type': raw['media_mime_type']?.toString(),
      'media_size': raw['media_size'],
      'created_at': raw['created_at'],
      'updated_at': raw['updated_at'],
      'is_updated': raw['is_updated'] == true,
      'reply_to_message_id': replyToId,
      'reply_to': replyTo,
    };
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
    if (_editingMessage != null) {
      await _submitEdit();
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final replyId = _pendingReplyToMessageId();

      final createdMessage = _normalizeMessageMap(
        await _messagesService.sendMessage(
          chatId: widget.chatId,
          text: text,
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      _messageController.clear();

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
        _replyingTo = null;
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

  Future<void> _showAttachmentPicker() async {
    if (_isUploadingChatAvatar) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: AppColors.accent),
                  title: const Text('Фото'),
                  onTap: () => Navigator.of(ctx).pop('photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.video_collection_outlined, color: AppColors.accent),
                  title: const Text('Видео'),
                  onTap: () => Navigator.of(ctx).pop('video_gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_outlined, color: AppColors.accent),
                  title: const Text('Снять видео'),
                  onTap: () => Navigator.of(ctx).pop('video_camera'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice == 'photo') {
      await _pickAndSendImage();
      return;
    }

    if (choice == 'video_gallery') {
      await _pickAndSendVideo(source: ImageSource.gallery);
      return;
    }

    if (choice == 'video_camera') {
      await _pickAndSendVideo(source: ImageSource.camera);
      return;
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isSendingImage) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2200,
      );

      if (picked == null) return;

      setState(() {
        _isSendingImage = true;
      });

      final replyId = _pendingReplyToMessageId();

      final createdMessage = _normalizeMessageMap(
        await _messagesService.sendPhotoMessage(
          chatId: widget.chatId,
          imagePath: picked.path,
          fileName: picked.name,
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
        _replyingTo = null;
        _isSendingImage = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            _extractErrorMessage(e, fallback: 'Не удалось отправить фото'),
          ),
        ),
      );
    }
  }

  Future<void> _pickAndSendVideo({required ImageSource source}) async {
    if (_isSendingVideo) return;

    try {
      final picked = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );

      if (picked == null) return;

      setState(() {
        _isSendingVideo = true;
      });

      final replyId = _pendingReplyToMessageId();

      final createdMessage = _normalizeMessageMap(
        await _messagesService.sendVideoMessage(
          chatId: widget.chatId,
          videoPath: picked.path,
          fileName: picked.name,
          replyToMessageId: replyId,
        ),
      );

      if (!mounted) return;

      final exists = _messages.any((m) => m['id'] == createdMessage['id']);

      setState(() {
        if (!exists) {
          _messages.add(createdMessage);
        }
        _replyingTo = null;
        _isSendingVideo = false;
      });

      await _markCurrentChatAsRead();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingVideo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            _extractErrorMessage(e, fallback: 'Не удалось отправить видео'),
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

  String? _senderAvatarUrl(Map<String, dynamic> message) {
    final rawSenderId = message['sender_id'];

    int? senderId;
    if (rawSenderId is int) {
      senderId = rawSenderId;
    } else {
      senderId = int.tryParse(rawSenderId.toString());
    }

    if (senderId == null) return null;
    return _memberAvatarUrls[senderId];
  }

  int? _intFromDynamic(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  String _senderNameForUserId(int? userId) {
    if (userId == null) return 'Пользователь';
    if (userId == _currentUserId) return 'Вы';
    return _memberNames[userId] ?? 'Пользователь';
  }

  String _replyPreviewLabel(Map<String, dynamic> reply) {
    final type = (reply['message_type'] ?? 'text').toString();
    if (type == 'image') {
      return '📷 Фото';
    }
    if (type == 'video') {
      return '🎥 Видео';
    }

    final t = (reply['text'] ?? '').toString().trim();
    if (t.isEmpty) {
      return 'Сообщение';
    }
    if (t.length > 90) {
      return '${t.substring(0, 90)}…';
    }
    return t;
  }

  Future<void> _showMessageActions(Map<String, dynamic> message) async {
    final isMine = _isMine(message);
    final messageId = _intFromDynamic(message['id']);
    if (messageId == null) return;

    final messageType = (message['message_type'] ?? 'text').toString();
    final text = (message['text'] ?? '').toString().trim();

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: AppColors.accent),
                  title: const Text('Ответить'),
                  onTap: () => Navigator.of(ctx).pop('reply'),
                ),
                if (text.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded, color: AppColors.textPrimary),
                    title: const Text('Копировать'),
                    onTap: () => Navigator.of(ctx).pop('copy'),
                  ),
                if (isMine && messageType == 'text' && text.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: AppColors.textPrimary),
                    title: const Text('Изменить'),
                    onTap: () => Navigator.of(ctx).pop('edit'),
                  ),
                if (isMine)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text('Удалить'),
                    onTap: () => Navigator.of(ctx).pop('delete'),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'reply') {
      setState(() {
        _replyingTo = Map<String, dynamic>.from(message);
        _editingMessage = null;
      });
      return;
    }

    if (action == 'copy' && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Текст скопирован')),
      );
      return;
    }

    if (action == 'edit') {
      setState(() {
        _editingMessage = Map<String, dynamic>.from(message);
        _replyingTo = null;
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      });
      return;
    }

    if (action == 'delete') {
      await _confirmDeleteMessage(messageId);
    }
  }

  Future<void> _confirmDeleteMessage(int messageId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Удалить сообщение?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await _messagesService.deleteMessage(messageId);

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
        if (_editingMessage != null && _editingMessage!['id'] == messageId) {
          _editingMessage = null;
          _messageController.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            _extractErrorMessage(e, fallback: 'Не удалось удалить сообщение'),
          ),
        ),
      );
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  int? _pendingReplyToMessageId() {
    if (_replyingTo == null) return null;
    return _intFromDynamic(_replyingTo!['id']);
  }

  Future<void> _submitEdit() async {
    final editing = _editingMessage;
    if (editing == null) return;

    final messageId = _intFromDynamic(editing['id']);
    if (messageId == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final updated = _normalizeMessageMap(
        await _messagesService.updateMessage(
          messageId: messageId,
          text: text,
        ),
      );

      if (!mounted) return;

      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == updated['id']);
        if (idx >= 0) {
          _messages[idx] = updated;
        }
        _editingMessage = null;
        _messageController.clear();
        _isSending = false;
      });

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
            _extractErrorMessage(e, fallback: 'Не удалось изменить сообщение'),
          ),
        ),
      );
    }
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

  Widget _buildReplyQuote(Map<String, dynamic> message, bool isMine) {
    final reply = message['reply_to'];
    if (reply is! Map) {
      return const SizedBox.shrink();
    }

    final map = Map<String, dynamic>.from(reply);
    final senderId = _intFromDynamic(map['sender_id']);
    final senderLabel = _senderNameForUserId(senderId);
    final preview = _replyPreviewLabel(map);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.black.withAlpha(20)
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: AppColors.accent.withAlpha(200),
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMine ? Colors.black.withAlpha(200) : AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMine ? Colors.black.withAlpha(200) : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> message, bool isMine) {
    final messageType = (message['message_type'] ?? 'text').toString();
    final mediaUrl = (message['media_url'] ?? '').toString().trim();

    if (messageType == 'image' && mediaUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 220,
          maxHeight: 280,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 220,
                height: 220,
                color: isMine
                    ? Colors.black.withAlpha(20)
                    : AppColors.surfaceSoft,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            },
            errorBuilder: (_, __, ___) {
              return Container(
                width: 220,
                height: 160,
                color: isMine
                    ? Colors.black.withAlpha(20)
                    : AppColors.surfaceSoft,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Не удалось загрузить фото',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isMine ? Colors.black : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (messageType == 'video' && mediaUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 240,
          maxHeight: 280,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _VideoMessageWidget(
            url: mediaUrl,
            isMine: isMine,
          ),
        ),
      );
    }

    return Text(
  (message['text'] ?? '').toString(),
  style: TextStyle(
        color: isMine ? Colors.black : AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = _isMine(message);
    final time = _formatTime(message['created_at']?.toString());
    final isUpdated = message['is_updated'] == true;
    final senderName = _senderName(message);
    final senderAvatarUrl = _senderAvatarUrl(message);

    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: () => _showMessageActions(message),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.70,
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
              _buildReplyQuote(message, isMine),
              _buildMessageContent(message, isMine),
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
      ),
    );

    if (_isGroupChat && !isMine) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: _buildCircleAvatar(
                title: senderName,
                avatarUrl: senderAvatarUrl,
                size: 34,
              ),
            ),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
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
            final label = _formatDateLabel(message['created_at']?.toString());

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
    final isEditing = _editingMessage != null;
    final reply = _replyingTo;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(235),
          border: Border(
            top: BorderSide(
              color: AppColors.accentBorder.withAlpha(100),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentBorder.withAlpha(110),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Редактирование сообщения',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _cancelEdit,
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isEditing && reply != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentBorder.withAlpha(110),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _senderName(reply),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _replyPreviewLabel(reply),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _cancelReply,
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                GestureDetector(
                  onTap: (isEditing || _isSendingImage || _isSendingVideo)
                      ? null
                      : () => _showAttachmentPicker(),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentBorder.withAlpha(110),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: (_isSendingImage || _isSendingVideo)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Icon(
                            Icons.photo_outlined,
                            color: isEditing ? AppColors.textMuted : AppColors.accent,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: isEditing
                          ? 'Новый текст сообщения...'
                          : 'Введите сообщение...',
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
                        : Icon(
                            isEditing ? Icons.check_rounded : Icons.send_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                  ),
                ),
              ],
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
    final visibleTitle = _chatTitle.trim().isNotEmpty ? _chatTitle : widget.title;

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
                      child: Row(
                        children: [
                          _buildSquareAvatar(
                            title: visibleTitle,
                            avatarUrl: _chatAvatarUrl,
                            size: 42,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              visibleTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isGroupChat)
  IconButton(
    tooltip: 'Изменить аватар группы',
    onPressed: _isUploadingChatAvatar ? null : _pickAndUploadChatAvatar,
    icon: _isUploadingChatAvatar
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          )
        : const Icon(
            Icons.photo_camera_outlined,
            color: AppColors.accent,
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