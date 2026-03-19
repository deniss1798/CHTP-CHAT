import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/services/create_chat_service.dart';
import '../../data/services/users_service.dart';

class UserPickerScreen extends StatefulWidget {
  const UserPickerScreen({super.key});

  @override
  State<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<UserPickerScreen> {
  final UsersService _usersService = UsersService();
  final CreateChatService _createChatService = CreateChatService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _usersService.getUsers();

      if (!mounted) return;

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      String message = 'Не удалось загрузить пользователей';

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

      Navigator.of(context).pop({
        'chat_id': chatId,
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
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });
    }
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
                onPressed: _loadUsers,
                child: const Text('Повторить'),
              ),
            ],
          ),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final username = (user['username'] ?? '').toString();
        final email = (user['email'] ?? '').toString();

        return GestureDetector(
          onTap: _isCreating ? null : () => _createPrivateChat(user),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(210),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.accentBorder.withAlpha(110),
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
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
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
                        Icons.arrow_forward_ios_rounded,
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
                        'Выбор пользователя',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Поиск по username или email',
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
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                    ),
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