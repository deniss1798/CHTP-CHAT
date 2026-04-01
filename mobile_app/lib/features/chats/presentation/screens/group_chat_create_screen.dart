import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/chat_avatar_service.dart';
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
  final ChatAvatarService _chatAvatarService = ChatAvatarService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;

  int? _currentUserId;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final Set<int> _selectedUserIds = <int>{};

  File? _selectedAvatarFile;

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

final userId = parsedUserId;

setState(() {
  if (_selectedUserIds.contains(userId)) {
    _selectedUserIds.remove(userId);
  } else {
    _selectedUserIds.add(userId);
  }
});
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
    double size = 54,
  }) {
    final safeUrl = (avatarUrl ?? '').trim();

    if (safeUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
                borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(18),
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

  Future<void> _pickGroupAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked == null) return;

    setState(() {
      _selectedAvatarFile = File(picked.path);
    });
  }

  void _removeGroupAvatar() {
    setState(() {
      _selectedAvatarFile = null;
    });
  }

  Widget _buildGroupAvatarPreview() {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Группа';

    if (_selectedAvatarFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.file(
          _selectedAvatarFile!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(title),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
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

      if (chatId == null) {
        throw Exception('Не удалось получить id созданной группы');
      }

      if (_selectedAvatarFile != null) {
        await _chatAvatarService.uploadChatAvatar(
          chatId: chatId,
          file: _selectedAvatarFile!,
        );
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              _buildGroupAvatarPreview(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isCreating ? null : _pickGroupAvatar,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _selectedAvatarFile == null
                          ? 'Выбрать аватар'
                          : 'Изменить аватар',
                    ),
                  ),
                  if (_selectedAvatarFile != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _isCreating ? null : _removeGroupAvatar,
                      icon: const Icon(Icons.close),
                      label: const Text('Убрать'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
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
                    final avatarUrl = _userAvatarUrl(user);

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
                            _buildUserAvatar(
                              title: username,
                              avatarUrl: avatarUrl,
                              size: 54,
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