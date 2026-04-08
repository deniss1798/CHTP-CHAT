import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/url_helper.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/chat_socket_service.dart';
import '../../data/services/local_chat_state_service.dart';
import '../../data/services/messages_service.dart';
import '../../data/services/presence_service.dart';
import 'chat_member_add_screen.dart';
import 'video_note_record_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../data/services/chat_avatar_service.dart';

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

class _VideoMessageWidget extends StatefulWidget {
  final String url;
  final bool isMine;
  final bool isVideoNote;

  /// Для обычного видео: открыть на весь экран. Для кружков ([isVideoNote]) не используется.
  final VoidCallback? onOpenFullscreen;

  const _VideoMessageWidget({
    required this.url,
    required this.isMine,
    this.isVideoNote = false,
    this.onOpenFullscreen,
  });

  @override
  State<_VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<_VideoMessageWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showOverlay = true;
  String? _initError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  void _attachController() {
    final gen = ++_loadGeneration;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _initError = null;

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _initError = 'Некорректный адрес видео';
      return;
    }

    final c = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = c;

    c.initialize().then((_) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _initialized = true;
        _initError = null;
      });
    }).catchError((Object e, _) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _initialized = false;
        _initError = e.toString().replaceFirst('Exception: ', '');
      });
    });

    if (widget.isVideoNote) {
      c.addListener(() {
        if (!mounted || gen != _loadGeneration) return;
        final playing = c.value.isPlaying;
        if (playing) {
          if (_showOverlay) setState(() => _showOverlay = false);
        } else {
          if (!_showOverlay) setState(() => _showOverlay = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    const loadingBg = Color(0x00000000);

    if (_initError != null) {
      return Container(
        color: loadingBg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Не удалось загрузить видео',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'На ПК иногда не поддерживается кодек с телефона. Повторите попытку.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(_attachController),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return Container(
        color: loadingBg,
        alignment: Alignment.center,
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent.withAlpha(220),
          ),
        ),
      );
    }

    final c = _controller!;

    final videoChild = widget.isVideoNote
        ? SizedBox(
            width: 220,
            height: 220,
            child: ClipOval(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          )
        : AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          );

    if (widget.isVideoNote) {
      return GestureDetector(
        onTap: _togglePlayback,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(child: videoChild),
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
                  c.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onOpenFullscreen,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: videoChild),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(55),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImageViewer extends StatelessWidget {
  final String url;

  const _FullscreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить фото',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  final String url;
  final bool isVideoNote;

  const _FullscreenVideoPage({
    required this.url,
    this.isVideoNote = false,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showOverlay = true;
  String? _initError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    final gen = ++_loadGeneration;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _initError = null;

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _initError = 'Некорректный адрес видео');
      return;
    }

    final c = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = c;

    c.initialize().then((_) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _initialized = true;
        _initError = null;
      });
    }).catchError((Object e, _) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _initialized = false;
        _initError = e.toString().replaceFirst('Exception: ', '');
      });
    });

    c.addListener(() {
      if (!mounted || gen != _loadGeneration) return;
      final playing = c.value.isPlaying;
      if (playing) {
        if (_showOverlay) setState(() => _showOverlay = false);
      } else {
        if (!_showOverlay) setState(() => _showOverlay = true);
      }
    });
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(_attach),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.accent),
                label: const Text(
                  'Повторить',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final c = _controller!;

    final videoChild = widget.isVideoNote
        ? LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide * 0.92;
              return SizedBox(
                width: side,
                height: side,
                child: ClipOval(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              );
            },
          )
        : AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          );

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: videoChild),
          AnimatedOpacity(
            opacity: _showOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(55),
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: Icon(
                c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
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
  final PresenceService _presenceService = PresenceService();

  bool _isUploadingChatAvatar = false;
  bool _isSendingImage = false;
  bool _isSendingVideo = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  int? _currentUserId;
  List<Map<String, dynamic>> _messages = [];

  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingMessage;

  String _chatTitle = '';
  String? _chatAvatarUrl;

  final Map<int, String> _memberNames = {};
  final Map<int, String?> _memberAvatarUrls = {};
  final Map<int, DateTime?> _memberLastSeen = {};

  Timer? _presenceTimer;

  static const Duration _peerOnlineThreshold = Duration(seconds: 120);

  /// user_id -> last_read_message_id (с сервера)
  final Map<int, int> _lastReadByUserId = {};

  Timer? _typingDebounce;
  Timer? _typingStopTimer;
  int? _typingUserId;

  bool get _isGroupChat => widget.chatType == 'group';

  bool _isPeerOnlineFromLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return false;
    final now = DateTime.now().toUtc();
    final t = lastSeen.toUtc();
    return now.difference(t) <= _peerOnlineThreshold;
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceService.ping();
    _presenceTimer = Timer.periodic(const Duration(seconds: 35), (_) async {
      if (!mounted) return;
      await _presenceService.ping();
      try {
        await _loadChatMembers();
        if (mounted) setState(() {});
      } catch (_) {}
    });
  }

  @override
  void initState() {
    super.initState();
    _chatTitle = widget.title;
    _chatAvatarUrl = widget.avatarUrl;
    _messageController.addListener(_onMessageTextChanged);
    _initChat();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _typingDebounce?.cancel();
    _typingStopTimer?.cancel();
    _messageController.removeListener(_onMessageTextChanged);
    _socketSubscription?.cancel();
    _chatSocketService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageTextChanged() {
    if (!_chatSocketService.isConnected) return;
    final hasText = _messageController.text.isNotEmpty;
    if (!hasText) {
      _typingDebounce?.cancel();
      _typingStopTimer?.cancel();
      _chatSocketService.sendTyping(false);
      return;
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 220), () {
      _chatSocketService.sendTyping(true);
      _typingStopTimer?.cancel();
      _typingStopTimer = Timer(const Duration(seconds: 3), () {
        _chatSocketService.sendTyping(false);
      });
    });
  }

  int? _privatePeerUserId() {
    if (_isGroupChat) return null;
    if (_currentUserId == null) return null;
    for (final id in _memberNames.keys) {
      if (id != _currentUserId) return id;
    }
    return null;
  }

  String _computeDeliveryForOutgoing(int messageId) {
    if (_isGroupChat) {
      final others =
          _memberNames.keys.where((id) => id != _currentUserId).toList();
      if (others.isEmpty) return 'sent';
      for (final uid in others) {
        final lr = _lastReadByUserId[uid] ?? 0;
        if (lr < messageId) return 'sent';
      }
      return 'read';
    }
    final peer = _privatePeerUserId();
    if (peer == null) return 'sent';
    final lr = _lastReadByUserId[peer] ?? 0;
    return lr >= messageId ? 'read' : 'sent';
  }

  void _applyReadReceiptToMessages(int userId, int lastReadId) {
    _lastReadByUserId[userId] = lastReadId;
    _memberLastSeen[userId] = DateTime.now().toUtc();
    if (!mounted) return;
    setState(() {
      _messages = _messages.map((m) {
        if (!_isMine(m)) return m;
        final mid = _intFromDynamic(m['id']);
        if (mid == null) return m;
        final copy = Map<String, dynamic>.from(m);
        copy['delivery_status'] = _computeDeliveryForOutgoing(mid);
        return copy;
      }).toList();
    });
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
    bool showOnlineDot = false,
  }) {
    final safeUrl = _normalizedAvatarUrl(avatarUrl);

    Widget inner;

    if (safeUrl != null && safeUrl.isNotEmpty) {
      inner = ClipRRect(
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
    } else {
      inner = Container(
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

    if (!showOnlineDot) return inner;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        inner,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
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
      _startPresenceHeartbeat();
      if (mounted && _messageController.text.trim().isNotEmpty) {
        _onMessageTextChanged();
      }
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
      _memberLastSeen.clear();

      for (final item in data) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final rawId = map['id'];
          final username = (map['username'] ?? '').toString().trim();
          final rawAvatar = (map['avatar_url'] ?? '').toString().trim();
          final rawSeen = map['last_seen_at'];

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
            if (rawSeen != null && rawSeen.toString().trim().isNotEmpty) {
              _memberLastSeen[userId] = DateTime.tryParse(rawSeen.toString());
            } else {
              _memberLastSeen[userId] = null;
            }
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
      _lastReadByUserId.clear();
      try {
        final rows = await _messagesService.getChatReadState(widget.chatId);
        for (final r in rows) {
          final uid = _intFromDynamic(r['user_id']);
          final lr = _intFromDynamic(r['last_read_message_id']);
          if (uid != null) {
            _lastReadByUserId[uid] = lr ?? 0;
          }
        }
      } catch (_) {}

      var normalizedMessages = messages.map(_normalizeMessageMap).toList();

      normalizedMessages = normalizedMessages.map((m) {
        if (_currentUserId == null) return m;
        if (!_isMine(m)) return m;
        final mid = _intFromDynamic(m['id']);
        if (mid == null) return m;
        final copy = Map<String, dynamic>.from(m);
        copy['delivery_status'] = _computeDeliveryForOutgoing(mid);
        return copy;
      }).toList();

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

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _chatSocketService.connect(
          chatId: widget.chatId,
          baseHttpUrl: ApiClient.baseUrl,
        );

        _socketSubscription = _chatSocketService.messagesStream.listen((message) {
          _handleSocketEvent(message);
        });
        return;
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }
  }

  void _handleSocketEvent(Map<String, dynamic> incoming) {
    if (incoming['type'] == 'typing') {
      final uid = _intFromDynamic(incoming['user_id']);
      if (uid == null || uid == _currentUserId) return;
      final typing = incoming['typing'] != false;
      if (!typing) {
        if (_typingUserId == uid) {
          setState(() => _typingUserId = null);
        }
        return;
      }
      setState(() {
        _typingUserId = uid;
        _memberLastSeen[uid] = DateTime.now().toUtc();
      });
      _typingStopTimer?.cancel();
      _typingStopTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          if (_typingUserId == uid) {
            _typingUserId = null;
          }
        });
      });
      return;
    }

    if (incoming['type'] == 'read_receipt') {
      final uid = _intFromDynamic(incoming['user_id']);
      final lr = _intFromDynamic(incoming['last_read_message_id']);
      if (uid == null || lr == null) return;
      if (uid == _currentUserId) return;
      _applyReadReceiptToMessages(uid, lr);
      return;
    }

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

      var normalized =
          _normalizeMessageMap(Map<String, dynamic>.from(msg));
      final incomingId = normalized['id'];
      if (_isMine(normalized)) {
        final mid = _intFromDynamic(normalized['id']);
        if (mid != null) {
          normalized = Map<String, dynamic>.from(normalized);
          normalized['delivery_status'] = _computeDeliveryForOutgoing(mid);
        }
      }

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

    var normalized = _normalizeMessageMap(payload);
    final incomingId = normalized['id'];
    final senderId = _intFromDynamic(normalized['sender_id']);
    if (_isMine(normalized)) {
      final mid = _intFromDynamic(normalized['id']);
      if (mid != null) {
        normalized = Map<String, dynamic>.from(normalized);
        normalized['delivery_status'] = _computeDeliveryForOutgoing(mid);
      }
    }
    final exists = _messages.any((m) => m['id'] == incomingId);

    if (exists) return;
    if (!mounted) return;

    setState(() {
      if (senderId != null &&
          senderId != _currentUserId &&
          !_isGroupChat) {
        _memberLastSeen[senderId] = DateTime.now().toUtc();
      }
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
      'media_url': UrlHelper.absoluteMediaUrl(raw['media_url']) ??
          raw['media_url']?.toString(),
      'media_mime_type': raw['media_mime_type']?.toString(),
      'media_size': raw['media_size'],
      'created_at': raw['created_at'],
      'updated_at': raw['updated_at'],
      'is_updated': raw['is_updated'] == true,
      'reply_to_message_id': replyToId,
      'reply_to': replyTo,
      'delivery_status': raw['delivery_status']?.toString(),
    };
  }

  Future<void> _markCurrentChatAsRead() async {
    if (_messages.isEmpty) return;

    final lastMessage = _messages.last;
    final lastMessageId = _intFromDynamic(lastMessage['id']);
    if (lastMessageId == null) return;

    try {
      await _messagesService.markChatRead(
        chatId: widget.chatId,
        messageId: lastMessageId,
      );
    } catch (_) {}

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
                  title: const Text('Видео (файл)'),
                  subtitle: const Text('Из галереи — обычное видео'),
                  onTap: () => Navigator.of(ctx).pop('video_gallery'),
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

  String _basenameFromPath(String path) {
    final n = path.replaceAll(r'\', '/').split('/').last;
    return n.isEmpty ? 'video_note.mp4' : n;
  }

  Future<void> _openVideoNoteRecorder() async {
    if (_isSendingVideo) return;

    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const VideoNoteRecordScreen(),
      ),
    );

    if (path == null || path.isEmpty) return;

    await _uploadVideoNote(path);
  }

  Future<void> _uploadVideoNote(String videoPath) async {
    if (_isSendingVideo) return;

    setState(() {
      _isSendingVideo = true;
    });

    try {
      final replyId = _pendingReplyToMessageId();

      final createdMessage = _normalizeMessageMap(
        await _messagesService.sendVideoNoteMessage(
          chatId: widget.chatId,
          videoPath: videoPath,
          fileName: _basenameFromPath(videoPath),
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
            _extractErrorMessage(e, fallback: 'Не удалось отправить видеосообщение'),
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
    if (type == 'video_note') {
      return '🎬 Видеосообщение';
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

  bool _isMediaOnlyMessage(Map<String, dynamic> message) {
    final type = (message['message_type'] ?? 'text').toString();
    if (type == 'text') return false;
    return (message['text'] ?? '').toString().trim().isEmpty;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
              ? Colors.black.withAlpha(28)
              : Colors.white.withAlpha(7),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: AppColors.accentBright.withAlpha(200),
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
                color: isMine ? AppColors.accentBright : AppColors.accent,
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
                color: isMine ? AppColors.textSecondary : AppColors.textSecondary,
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

  void _openFullscreenImage(String url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _FullscreenImageViewer(url: url),
      ),
    );
  }

  void _openFullscreenVideo(String url, {required bool isVideoNote}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _FullscreenVideoPage(url: url, isVideoNote: isVideoNote),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> message, bool isMine) {
    final messageType = (message['message_type'] ?? 'text').toString();
    final mediaUrl = (message['media_url'] ?? '').toString().trim();

    if (messageType == 'video_note' && mediaUrl.isNotEmpty) {
      return SizedBox(
        width: 220,
        height: 220,
        child: _VideoMessageWidget(
          url: mediaUrl,
          isMine: isMine,
          isVideoNote: true,
        ),
      );
    }

    if (messageType == 'image' && mediaUrl.isNotEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openFullscreenImage(mediaUrl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 220,
            maxHeight: 280,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 220,
                  height: 220,
                  color: Colors.black.withAlpha(14),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent.withAlpha(220),
                    ),
                  ),
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
          borderRadius: BorderRadius.circular(12),
          child: _VideoMessageWidget(
            url: mediaUrl,
            isMine: isMine,
            isVideoNote: false,
            onOpenFullscreen: () => _openFullscreenVideo(mediaUrl, isVideoNote: false),
          ),
        ),
      );
    }

    return Text(
  (message['text'] ?? '').toString(),
  style: TextStyle(
        color: isMine ? AppColors.textPrimary : AppColors.textPrimary,
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
    final mediaOnly = _isMediaOnlyMessage(message);
    final messageType = (message['message_type'] ?? 'text').toString();
    final isVideoNote = messageType == 'video_note';
    final hasReplyPreview = message['reply_to'] is Map;
    final videoNoteCircleLayout = mediaOnly &&
        isVideoNote &&
        !hasReplyPreview &&
        !_isGroupChat;

    Widget mainContent = _buildMessageContent(message, isMine);
    if (mediaOnly) {
      mainContent = ClipRRect(
        borderRadius: BorderRadius.circular(
          isVideoNote ? 999 : 12,
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            mainContent,
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUpdated)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          'изм.',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFFE8EAED),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bubbleShape = videoNoteCircleLayout
        ? BorderRadius.circular(110)
        : BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          );

    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: bubbleShape,
        splashColor: mediaOnly ? Colors.transparent : Colors.white.withAlpha(28),
        highlightColor: mediaOnly ? Colors.transparent : null,
        onLongPress: () => _showMessageActions(message),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: mediaOnly
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: mediaOnly
                ? Colors.transparent
                : (isMine ? AppColors.bubbleMine : AppColors.bubbleOther),
            borderRadius: bubbleShape,
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
                      color: AppColors.accentBright,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              _buildReplyQuote(message, isMine),
              mainContent,
              if (!mediaOnly) const SizedBox(height: 8),
              if (!mediaOnly)
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
                                ? AppColors.textMuted
                                : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isMine) ...[
                      Icon(
                        (message['delivery_status']?.toString() == 'read')
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 15,
                        color: (message['delivery_status']?.toString() == 'read')
                            ? AppColors.accentBright
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      time,
                      style: TextStyle(
                        color: isMine ? AppColors.textMuted : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.background.withAlpha(245),
          border: Border(
            top: BorderSide(
              color: Colors.white.withAlpha(14),
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
                    borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.accentBright,
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
                Tooltip(
                  message: 'Фото или видео из галереи',
                  child: GestureDetector(
                    onTap: (isEditing || _isSendingImage || _isSendingVideo)
                        ? null
                        : () => _showAttachmentPicker(),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: (_isSendingImage || _isSendingVideo)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : Icon(
                              Icons.perm_media_outlined,
                              color: isEditing ? AppColors.textMuted : AppColors.accentBright,
                              size: 22,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Видеосообщение (кружок) — удерживайте кнопку записи',
                  child: GestureDetector(
                    onTap: (isEditing || _isSendingImage || _isSendingVideo)
                        ? null
                        : _openVideoNoteRecorder,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: (_isSendingImage || _isSendingVideo)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : Icon(
                              Icons.videocam_outlined,
                              color: isEditing ? AppColors.textMuted : AppColors.accentBright,
                              size: 22,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Color(0xFF0C0E12)),
                            ),
                          )
                        : Icon(
                            isEditing ? Icons.check_rounded : Icons.send_rounded,
                            color: const Color(0xFF0C0E12),
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
        if (_typingUserId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_senderNameForUserId(_typingUserId)} печатает…',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Expanded(child: _buildMessagesList()),
        _buildInputBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTitle = _chatTitle.trim().isNotEmpty ? _chatTitle : widget.title;
    final peerId = _privatePeerUserId();
    final peerOnline = !_isGroupChat &&
        peerId != null &&
        _isPeerOnlineFromLastSeen(_memberLastSeen[peerId]);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        showAmbientGlow: false,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(240),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withAlpha(12),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (widget.onBackOverride != null) {
                          widget.onBackOverride!();
                        } else {
                          Navigator.of(context).pop(true);
                        }
                      },
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
                            showOnlineDot: peerOnline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  visibleTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (!_isGroupChat) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    peerOnline ? 'в сети' : 'не в сети',
                                    style: TextStyle(
                                      color: peerOnline
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
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