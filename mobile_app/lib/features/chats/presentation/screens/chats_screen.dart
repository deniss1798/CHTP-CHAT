import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/services/chats_service.dart';
import 'chat_detail_screen.dart';
import 'group_chat_create_screen.dart';
import 'user_picker_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatsService _chatsService = ChatsService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  List<Map<String, dynamic>> _allChats = [];
  List<Map<String, dynamic>> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {

    _searchController.dispose();
    super.dispose();
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
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          title: title,
          chatType: chatType,
          avatarUrl: avatarUrl,
        ),
      ),
    );

    if (result == true) {
      await _loadChats();
    }
  }

  Future<void> _openCreateChatSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                _CreateChatOption(
                  icon: Icons.person_outline,
                  title: 'Личный чат',
                  subtitle: 'Выбрать пользователя по username',
                  onTap: () => Navigator.of(context).pop('private'),
                ),
                const SizedBox(height: 12),
                _CreateChatOption(
                  icon: Icons.group_outlined,
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
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    final now = DateTime.now();
    final local = dt.toLocal();

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

  int _unreadCount(Map<String, dynamic> chat) {
    final value = chat['unread_count'] ?? chat['unreadCount'] ?? 0;

    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
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
    double size = 62,
  }) {
    final safeUrl = (avatarUrl ?? '').trim();

    if (safeUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(title),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
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
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(title),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w800,
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        itemCount: _filteredChats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
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

          final isUnread = unreadCount > 0;

          return GestureDetector(
            onTap: chatId == null
                ? null
                : () => _openChat(
                      chatId: chatId!,
                      title: title,
                      chatType: (chat['type'] ?? '').toString(),
                      avatarUrl: avatarUrl,
                    ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUnread
                    ? const Color(0xFF17131B)
                    : AppColors.surface.withAlpha(215),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isUnread
                      ? AppColors.accent.withAlpha(200)
                      : AppColors.accentBorder.withAlpha(120),
                  width: isUnread ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUnread
                        ? AppColors.accent.withAlpha(30)
                        : AppColors.accent.withAlpha(12),
                    blurRadius: isUnread ? 22 : 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChatAvatar(
                    title: title,
                    avatarUrl: avatarUrl,
                    size: 62,
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
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 14,
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
          );
        },
      ),
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
          child: Stack(
            children: [
              Positioned(
                bottom: 40,
                right: -30,
                child: _GlowCircle(
                  size: 180,
                  color: AppColors.accent.withAlpha(24),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'ЧТП',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withAlpha(180),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.accentBorder.withAlpha(120),
                                ),
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileScreen(),
                                    ),
                                  );

                                  if (!mounted) return;
                                  await _loadChats(silent: true);
                                },
                                icon: const Icon(
                                  Icons.person_outline,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withAlpha(180),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.accentBorder.withAlpha(120),
                                ),
                              ),
                              child: IconButton(
                                onPressed: () => _logout(context),
                                icon: const Icon(
                                  Icons.logout,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Сообщения',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
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
                            fillColor: AppColors.surfaceSoft,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
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
                right: 20,
                bottom: 20,
                child: GestureDetector(
                  onTap: _openCreateChatSheet,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withAlpha(70),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.add,
                      color: Colors.black,
                      size: 34,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentBorder.withAlpha(100),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.black,
                size: 24,
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
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size / 2,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}