import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_content_frame.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
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

  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isCreating = false;
  String? _error;
  String? _searchError;

  int? _currentUserId;
  List<Map<String, dynamic>> _searchResults = [];
  final Map<int, Map<String, dynamic>> _selectedUsersCache = {};
  final Set<int> _selectedUserIds = <int>{};

  File? _selectedAvatarFile;

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _extractErrorMessage(
          e,
          fallback: 'Не удалось загрузить профиль',
        );
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final q = _searchController.text.trim();

    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    if (q.length < 2) {
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
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
      _searchError = null;
    });

    try {
      final users = await _usersService.searchUsers(q);
      final me = _currentUserId;

      if (!mounted) return;

      final filtered = users.where((u) {
        final rawUserId = u['id'];
        int? userId;
        if (rawUserId is int) {
          userId = rawUserId;
        } else {
          userId = int.tryParse(rawUserId.toString());
        }
        return userId != null && userId != me;
      }).toList();

      setState(() {
        _searchResults = filtered;
        _isSearching = false;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _searchError = _extractErrorMessage(
          e,
          fallback: 'Не удалось выполнить поиск',
        );
        _isSearching = false;
      });
    }
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
        _selectedUsersCache.remove(userId);
      } else {
        _selectedUserIds.add(userId);
        _selectedUsersCache[userId] = Map<String, dynamic>.from(user);
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
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          _selectedAvatarFile!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: AppGradients.accentPanel,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.primaryButton,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(title),
        style: const TextStyle(
          color: AppColors.textOnAccent,
          fontSize: 22,
          fontWeight: FontWeight.w800,
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
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _usersForList() {
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      return _searchResults;
    }
    final ids = _selectedUserIds.toList()..sort();
    return ids
        .map((id) => _selectedUsersCache[id])
        .whereType<Map<String, dynamic>>()
        .toList();
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
                onPressed: () {
                  final q = _searchController.text.trim();
                  if (q.isEmpty) {
                    setState(() => _error = null);
                    _init();
                  } else {
                    _performSearch();
                  }
                },
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
          child: AppSurface(
            tone: AppSurfaceTone.elevated,
            radius: AppRadius.xxl,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              children: [
                _buildGroupAvatarPreview(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isCreating ? null : _pickGroupAvatar,
                      icon: const Icon(AppIcons.photoLibrary),
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
                        icon: const Icon(AppIcons.close),
                        label: const Text('Убрать'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: AppSurface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            shadow: AppShadows.lift,
            child: TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Название группы',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: AppSurface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            shadow: AppShadows.lift,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск участников',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(AppIcons.search, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Выбрано: ${_selectedUserIds.length}',
              style: TextStyle(
                color: _selectedUserIds.isNotEmpty
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildUserListArea(),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createGroupChat,
                child: _isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
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

  Widget _buildUserListArea() {
    final q = _searchController.text.trim();

    if (q.isEmpty) {
      if (_selectedUserIds.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Введите username или email, чтобы найти участников',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
        );
      }
      final selectedOnly = _usersForList();
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: selectedOnly.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildUserTile(selectedOnly[index]);
        },
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _searchError!,
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

    if (_searchResults.isEmpty) {
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
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
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
      child: AppSurface(
        tone: isSelected ? AppSurfaceTone.selected : AppSurfaceTone.base,
        radius: AppRadius.xl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: isSelected
            ? AppColors.accent.withAlpha(180)
            : AppColors.strokeSoft,
        shadow: isSelected ? [...AppShadows.lift, ...AppShadows.accentStroke] : AppShadows.lift,
        child: Row(
          children: [
            _buildUserAvatar(
              title: username,
              avatarUrl: avatarUrl,
              size: AppSizes.listAvatar,
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
                    ? AppIcons.checkCircle
                    : AppIcons.radioOff,
                size: AppSizes.iconMd,
                color: isSelected
                    ? AppColors.accentBright
                    : AppColors.textMuted,
              ),
            ],
          ),
        ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 16, 8),
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
                        'Новая группа',
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
              Expanded(
                child: AppContentFrame(
                  maxWidth: AppBreakpoints.formPanelMaxWidth,
                  padding: EdgeInsets.zero,
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
