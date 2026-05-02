import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_avatar.dart';
import '../../../../app/widgets/app_card.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../app/widgets/app_text_field.dart';
import '../../data/services/create_chat_service.dart';
import '../../data/services/users_service.dart';
import '../controllers/user_presentation_helpers.dart';

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
  static const _recentSearchesKey = 'user_picker_recent_searches';
  static const _maxRecentSearches = 5;

  final UsersService _usersService = UsersService();
  final CreateChatService _createChatService = CreateChatService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  bool _isSearching = false;
  bool _isCreating = false;
  String? _error;

  List<Map<String, dynamic>> _filteredUsers = [];
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecentSearches());
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

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_recentSearchesKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _recentSearches = values
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(_maxRecentSearches)
          .toList();
    });
  }

  Future<void> _saveRecentSearch(String value) async {
    final q = value.trim();
    if (q.length < 2) return;

    final next = <String>[
      q,
      ..._recentSearches.where((item) => item.toLowerCase() != q.toLowerCase()),
    ].take(_maxRecentSearches).toList();

    setState(() {
      _recentSearches = next;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, next);
  }

  Future<void> _removeRecentSearch(String value) async {
    final next = _recentSearches
        .where((item) => item.toLowerCase() != value.toLowerCase())
        .toList();
    setState(() {
      _recentSearches = next;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() {
      _recentSearches = [];
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  void _applyRecentSearch(String value) {
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
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

      await _saveRecentSearch(q);
      if (!mounted) return;

      setState(() {
        _filteredUsers = users;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = extractFeatureErrorMessage(
          e,
          fallback: 'Не удалось выполнить поиск',
        );
        _isSearching = false;
      });
    }
  }

  Future<void> _createPrivateChat(Map<String, dynamic> user) async {
    final userId = userIdFromMap(user);
    final username = (user['username'] ?? 'Чат').toString();

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            extractFeatureErrorMessage(
              e,
              fallback: 'Не удалось создать чат',
            ),
          ),
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
      return Center(
        child: _UserSearchEmptyState(
          recentSearches: _recentSearches,
          onRecentTap: _applyRecentSearch,
          onRecentRemove: (value) => unawaited(_removeRecentSearch(value)),
          onRecentClear: () => unawaited(_clearRecentSearches()),
        ),
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
        final avatarUrl = avatarUrlFromUserMap(user);

        return GestureDetector(
          onTap: _isCreating ? null : () => _createPrivateChat(user),
          child: AppCard(
            radius: AppRadius.xl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AppAvatar(
                  title: username,
                  imageUrl: avatarUrl,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.contentMaxWidth,
              ),
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
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Поиск по username',
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 2, 22, 8),
                child: Text(
                  'Ищите по точному username (учитывается регистр)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: _buildBody(),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserSearchEmptyState extends StatelessWidget {
  const _UserSearchEmptyState({
    required this.recentSearches,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onRecentClear,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final VoidCallback onRecentClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
            'Найдите пользователя',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Введите username в строке поиска выше.\nМы покажем подходящие результаты.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (recentSearches.isNotEmpty) ...[
            const SizedBox(height: 28),
            _UserSearchInfoCard(
              title: 'Недавние поиски',
              icon: Icons.history_rounded,
              trailing: GestureDetector(
                onTap: onRecentClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Очистить',
                    style: TextStyle(
                      color: AppColors.accentBright.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final search in recentSearches)
                    _RecentSearchChip(
                      search,
                      onTap: () => onRecentTap(search),
                      onRemove: () => onRecentRemove(search),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const _UserSearchInfoCard(
            title: 'Подсказки',
            icon: Icons.lightbulb_outline_rounded,
            child: Column(
              children: [
                _TipLine('Ищите по точному username (учитывается регистр)'),
                _TipLine('Username — это уникальное имя пользователя'),
                _TipLine('Нажмите на результат, чтобы начать чат'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSearchInfoCard extends StatelessWidget {
  const _UserSearchInfoCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      radius: AppRadius.xl,
      borderColor: AppColors.accent.withValues(alpha: 0.22),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentBright, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip(
    this.label, {
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary.withValues(alpha: 0.75),
                    size: 16,
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

class _TipLine extends StatelessWidget {
  const _TipLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              color: AppColors.accent,
              size: 4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.96),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
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
