import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/create_chat_service.dart';
import '../../data/services/users_service.dart';

class GroupChatCreateScreen extends StatefulWidget {
  const GroupChatCreateScreen({super.key});

  @override
  State<GroupChatCreateScreen> createState() => _GroupChatCreateScreenState();
}

class _GroupChatCreateScreenState extends State<GroupChatCreateScreen> {
  final UsersService _usersService = UsersService();
  final CreateChatService _createChatService = CreateChatService();
  final AuthService _authService = AuthService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;

  int? _currentUserId;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final Set<int> _selectedUserIds = <int>{};

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final me = await _authService.getMe();
      final rawId = me['id'];

      if (rawId is int) {
        _currentUserId = rawId;
      } else {
        _currentUserId = int.tryParse(rawId.toString());
      }

      final users = await _usersService.getUsers();

      final filtered = users.where((u) {
        final rawUserId = u['id'];
        int? userId;

        if (rawUserId is int) {
          userId = rawUserId;
        } else {
          userId = int.tryParse(rawUserId.toString());
        }

        return userId != null && userId != _currentUserId;
      }).toList();

      if (!mounted) return;

      setState(() {
        _allUsers = filtered;
        _filteredUsers = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _extractErrorMessage(
          e,
          fallback: 'Не удалось загрузить пользователей',
        );
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((user) {
          final username = (user['username'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          return username.contains(query) || email.contains(query);
        }).toList();
      }
    });
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

  void _toggleUser(Map<String, dynamic> user) {
    final rawId = user['id'];
    int? parsedUserId;

    if (rawId is int) {
      parsedUserId = rawId;
    } else {
      parsedUserId = int.tryParse(rawId.toString());
    }

    if (parsedUserId == null) return;

    setState(() {
      if (_selectedUserIds.contains(parsedUserId!)) {
        _selectedUserIds.remove(parsedUserId);
      } else {
        _selectedUserIds.add(parsedUserId);
      }
    });
  }

  Future<void> _createGroupChat() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название группы')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного участника')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final created = await _createChatService.createGroupChat(
        title: title,
        memberIds: _selectedUserIds.toList(),
      );

      final rawChatId = created['id'];
      int? chatId;

      if (rawChatId is int) {
        chatId = rawChatId;
      } else {
        chatId = int.tryParse(rawChatId.toString());
      }

      if (!mounted) return;

      Navigator.of(context).pop({
        'chat_id': chatId,
        'chat_title': title,
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _extractErrorMessage(
              e,
              fallback: 'Не удалось создать групповой чат',
            ),
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
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
                onPressed: _init,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: TextField(
            controller: _titleController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Название группы',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceSoft,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Поиск участников',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceSoft,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Выбрано: ${_selectedUserIds.length}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredUsers.isEmpty
              ? const Center(
                  child: Text(
                    'Пользователи не найдены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final username = (user['username'] ?? '').toString();
                    final email = (user['email'] ?? '').toString();

                    final rawId = user['id'];
                    int? userId;
                    if (rawId is int) {
                      userId = rawId;
                    } else {
                      userId = int.tryParse(rawId.toString());
                    }

                    final isSelected =
                        userId != null && _selectedUserIds.contains(userId);

                    return GestureDetector(
                      onTap: () => _toggleUser(user),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF17131B)
                              : AppColors.surface.withAlpha(210),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.accentBorder.withAlpha(110),
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createGroupChat,
                child: _isCreating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text('Создать группу'),
              ),
            ),
          ),
        ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Новая группа',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
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