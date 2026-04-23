import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_content_frame.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../core/network/api_client.dart';
import '../../data/services/create_chat_service.dart';
import '../../data/services/users_service.dart';

class UserPickerScreen extends StatefulWidget {
  const UserPickerScreen({
    super.key,
    this.embedded = false,
    this.onPrivateChatCreated,
  });

  /// Во вкладке «Контакты» [MessengerDesktopShell]: без кнопки «Назад».
  final bool embedded;

  /// Если [embedded], вместо [Navigator.pop] открываем чат в основной колонке.
  final void Function({required int chatId, required String title})?
      onPrivateChatCreated;

  @override
  State<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<UserPickerScreen> {
  final UsersService _usersService = UsersService();
  final CreateChatService _createChatService = CreateChatService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  bool _isSearching = false;
  bool _isCreating = false;
  String? _error;

  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _filteredUsers = [];
        _error = null;
        _isSearching = false;
      });
      return;
    }

    if (q.length < 2) {
      setState(() {
        _filteredUsers = [];
        _error = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final users = await _usersService.searchUsers(q);

      if (!mounted) return;

      setState(() {
        _filteredUsers = users;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      String message = 'Не удалось выполнить поиск';

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
        _isSearching = false;
      });
    }
  }

  String _initials(String title) {
    final parts =
        title.split(' ').where((e) => e.trim().isNotEmpty).take(2).toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      final word = parts.first.trim();
      return word.isNotEmpty ? word[0].toUpperCase() : '?';
    }

    final first = parts[0].trim();
    final second = parts[1].trim();

    final firstChar = first.isNotEmpty ? first[0].toUpperCase() : '';
    final secondChar = second.isNotEmpty ? second[0].toUpperCase() : '';

    final result = '$firstChar$secondChar'.trim();
    return result.isEmpty ? '?' : result;
  }

  String? _userAvatarUrl(Map<String, dynamic> user) {
    final possible = [
      user['avatar_url'],
      user['avatarUrl'],
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

  Widget _buildUserAvatar({
    required String title,
    required String? avatarUrl,
    double size = AppSizes.listAvatar,
  }) {
    final safeUrl = (avatarUrl ?? '').trim();
    final r = size * 0.28;

    if (safeUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.network(
          safeUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: AppGradients.accentPanel,
                borderRadius: BorderRadius.circular(r),
                boxShadow: AppShadows.primaryButton,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(title),
                style: TextStyle(
                  color: AppColors.textOnAccent,
                  fontSize: size * 0.36,
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
        gradient: AppGradients.accentPanel,
        borderRadius: BorderRadius.circular(r),
        boxShadow: AppShadows.primaryButton,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(title),
        style: TextStyle(
          color: AppColors.textOnAccent,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _createPrivateChat(Map<String, dynamic> user) async {
    final rawUserId = user['id'];
    final username = (user['username'] ?? 'Чат').toString();

    int? userId;
    if (rawUserId is int) {
      userId = rawUserId;
    } else {
      userId = int.tryParse(rawUserId.toString());
    }

    if (userId == null) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final createdChat = await _createChatService.createPrivateChat(
        userId: userId,
      );

      final chatId = createdChat['id'];

      if (!mounted) return;

      final id = chatId is int ? chatId : int.tryParse(chatId.toString());
      if (id == null) return;

      if (widget.embedded && widget.onPrivateChatCreated != null) {
        widget.onPrivateChatCreated!(chatId: id, title: username);
        return;
      }

      Navigator.of(context).pop({
        'chat_id': id,
        'chat_title': username,
      });
    } catch (e) {
      if (!mounted) return;

      String message = 'Не удалось создать чат';

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Widget _buildBody() {
    final query = _searchController.text.trim();

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
                onPressed: _performSearch,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (query.isEmpty) {
      return const Center(
        child: _UserSearchEmptyState(),
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Text(
          'Пользователи не найдены',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _filteredUsers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final username = (user['username'] ?? '').toString();
        final email = (user['email'] ?? '').toString();
        final avatarUrl = _userAvatarUrl(user);

        return GestureDetector(
          onTap: _isCreating ? null : () => _createPrivateChat(user),
          child: AppSurface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shadow: AppShadows.lift,
            child: Row(
              children: [
                _buildUserAvatar(
                  title: username,
                  avatarUrl: avatarUrl,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(
                        AppIcons.chevronRight,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 16, 4),
                child: Row(
                  children: [
                    if (!widget.embedded) ...[
                      AppIconButtonSurface(
                        icon: AppIcons.back,
                        tooltip: 'Назад',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        widget.embedded ? 'Контакты' : 'Кому написать',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: AppContentFrame(
                  maxWidth: AppBreakpoints.contentMaxWidth,
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск по имени',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: AppColors.chatListCard,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      prefixIcon: const Icon(
                        AppIcons.search,
                        color: AppColors.textMuted,
                        size: 22,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                          color: AppColors.accentBorder,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                          color: AppColors.accent,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AppContentFrame(
                  maxWidth: AppBreakpoints.contentMaxWidth,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserSearchEmptyState extends StatelessWidget {
  const _UserSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 260,
            height: 220,
            child: CustomPaint(
              painter: const _UserSearchEmptyDecorPainter(),
              child: const Center(
                child: _UserSearchGlowingOrb(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Введите username, чтобы найти пользователя',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Начните вводить имя пользователя в строке поиска выше. Мы покажем подходящие результаты.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSearchGlowingOrb extends StatelessWidget {
  const _UserSearchGlowingOrb();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.32),
                blurRadius: 60,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.2),
                blurRadius: 18,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_search_rounded,
            size: 60,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _UserSearchEmptyDecorPainter extends CustomPainter {
  const _UserSearchEmptyDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final r = 58.0 + i * 26.0;
      _paintDashedRing(
        canvas,
        c,
        r,
        AppColors.textSecondary.withValues(alpha: 0.18 - i * 0.03),
      );
    }

    final marks = [
      (0.35, 72.0),
      (1.25, 78.0),
      (2.1, 68.0),
    ];
    for (var i = 0; i < marks.length; i++) {
      final a = marks[i].$1;
      final rad = marks[i].$2;
      final col = [
        AppColors.accent,
        AppColors.textSecondary,
        AppColors.textMuted,
      ][i];
      final p = Offset(
        c.dx + rad * math.cos(a),
        c.dy + rad * math.sin(a),
      );
      canvas.drawCircle(
        p,
        2.4,
        Paint()..color = col.withValues(alpha: 0.45),
      );
    }
  }

  void _paintDashedRing(Canvas canvas, Offset center, double r, Color color) {
    const dash = 5.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    var distance = 0.0;
    final circum = 2 * math.pi * r;
    while (distance < circum) {
      final startAngle = (distance / circum) * 2 * math.pi - math.pi / 2;
      final endDist = math.min(distance + dash, circum);
      final sweep = ((endDist - distance) / circum) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngle,
        sweep,
        false,
        paint,
      );
      distance = endDist + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
