import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_avatar.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../app/widgets/app_text_field.dart';
import '../../data/services/chats_service.dart';
import '../../data/services/users_service.dart';
import '../controllers/user_presentation_helpers.dart';

class ChatMemberAddScreen extends StatefulWidget {
  final int chatId;
  final Set<int> existingMemberIds;

  const ChatMemberAddScreen({
    super.key,
    required this.chatId,
    required this.existingMemberIds,
  });

  @override
  State<ChatMemberAddScreen> createState() => _ChatMemberAddScreenState();
}

class _ChatMemberAddScreenState extends State<ChatMemberAddScreen> {
  final UsersService _usersService = UsersService();
  final ChatsService _chatsService = ChatsService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  bool _isSearching = false;
  bool _isAdding = false;
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final q = _searchController.text.trim();
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
    _searchDebounce = Timer(const Duration(milliseconds: 400), _performSearch);
  }

  Future<void> _performSearch() async {
    final q = _searchController.text.trim();
    if (q.length < 2) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final users = await _usersService.searchUsers(q);
      if (!mounted) return;
      final filtered = users.where((user) {
        final userId = userIdFromMap(user);
        return userId != null && !widget.existingMemberIds.contains(userId);
      }).toList();

      setState(() {
        _filteredUsers = filtered;
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

  Future<void> _addMember(Map<String, dynamic> user) async {
    final userId = userIdFromMap(user);
    if (userId == null || _isAdding) return;

    setState(() {
      _isAdding = true;
    });

    try {
      await _chatsService.addMemberToChat(
        chatId: widget.chatId,
        userId: userId,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(
            extractFeatureErrorMessage(
              e,
              fallback: 'Не удалось добавить участника',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  Widget _buildBody() {
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

    if (_searchController.text.trim().length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Введите минимум 2 символа username — поиск на сервере (как в контактах).',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
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
            fontWeight: FontWeight.w600,
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

        return GestureDetector(
          onTap: _isAdding ? null : () => _addMember(user),
          child: AppSurface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shadow: AppShadows.lift,
            child: Row(
              children: [
                AppAvatar(
                  title: username,
                  size: AppSizes.listAvatar,
                  square: true,
                  radius: AppRadius.md,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    username,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(
                        AppIcons.personAdd,
                        color: AppColors.accent,
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
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.strokeSoft),
                  ),
                ),
                child: Row(
                  children: [
                    AppIconButtonSurface(
                      icon: AppIcons.back,
                      tooltip: 'Назад',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Добавить участника',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Поиск по username',
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
                child: Text(
                  'Не менее 2 символов; регистр не важен.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
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
