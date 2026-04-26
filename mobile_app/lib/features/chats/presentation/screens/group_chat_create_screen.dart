import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
    if (safeUrl.isNotEmpty) {
      return ClipOval(
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
                shape: BoxShape.circle,
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
        shape: BoxShape.circle,
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

  /// Макет: тёмный квадрат со скруглением, пунктирное кольцо вокруг него, «+» на углу квадрата.
  static const double _groupAvatarSize = 104;
  static const double _groupAvatarR = 20;
  /// Внешний холст: кольцо визуально обводит квадрат.
  static const double _groupAvatarOrbit = 160;

  Widget _buildGroupAvatarSquare(String title) {
    final r = _groupAvatarR;
    if (_selectedAvatarFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.file(
          _selectedAvatarFile!,
          width: _groupAvatarSize,
          height: _groupAvatarSize,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: _groupAvatarSize,
      height: _groupAvatarSize,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(r),
      ),
      alignment: Alignment.center,
      child: title.trim().isEmpty
          ? Icon(
              AppIcons.group,
              size: 44,
              color: AppColors.accent,
            )
          : Text(
              _initials(title),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _buildAvatarPanel(String title) {
    return AppSurface(
      tone: AppSurfaceTone.elevated,
      radius: AppRadius.xl,
      borderColor: AppColors.accent.withValues(alpha: 0.32),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      shadow: null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: _FaintLineArtOverlay(),
          ),
          Column(
            children: [
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: _groupAvatarOrbit,
                  height: _groupAvatarOrbit,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(_groupAvatarOrbit, _groupAvatarOrbit),
                        painter: _DashedRingPainter(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(
                        width: _groupAvatarSize,
                        height: _groupAvatarSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            _buildGroupAvatarSquare(title),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isCreating ? null : _pickGroupAvatar,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.background,
                                        width: 2.5,
                                      ),
                                      boxShadow: AppShadows.lift,
                                    ),
                                    child: const Icon(
                                      AppIcons.add,
                                      color: AppColors.textOnAccent,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _isCreating ? null : _pickGroupAvatar,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: const Icon(AppIcons.photo, size: 20),
                label: Text(
                  _selectedAvatarFile == null
                      ? 'Выбрать аватар'
                      : 'Изменить аватар',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_selectedAvatarFile != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isCreating ? null : _removeGroupAvatar,
                  child: const Text(
                    'Убрать фото',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Widget prefix,
  }) {
    const r = 28.0;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.75),
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      prefixIcon: prefix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(r)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(r)),
        borderSide: BorderSide(
          color: AppColors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(r)),
        borderSide: BorderSide(color: AppColors.accent, width: 1.2),
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

    final t = _titleController.text.trim();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: _buildAvatarPanel(t),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: _fieldDecoration(
              hint: 'Название группы',
              prefix: const Icon(
                AppIcons.personAdd,
                color: AppColors.accent,
                size: 22,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: _fieldDecoration(
              hint: 'Поиск участников',
              prefix: const Icon(
                AppIcons.search,
                color: AppColors.accent,
                size: 22,
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
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _buildUserListArea(),
        ),
        const SizedBox(height: 20),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createGroupChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textOnAccent,
                          ),
                        ),
                      )
                    : const Text(
                        'Создать группу',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
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
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 28),
                    child: CustomPaint(
                      painter: _DashedRRectPainter(
                        color: AppColors.textSecondary.withValues(alpha: 0.45),
                        borderRadius: 20,
                        strokeWidth: 1.2,
                        dash: 5,
                        gap: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 44,
                              color: AppColors.accent.withValues(alpha: 0.92),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Информация о участниках появится здесь',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Начните вводить имя или email для поиска',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary
                                    .withValues(alpha: 0.92),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.formPanelMaxWidth,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
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
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                      ],
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

class _FaintLineArtOverlay extends StatelessWidget {
  const _FaintLineArtOverlay();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.textPrimary.withValues(alpha: 0.08);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 2,
            top: 4,
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 30,
              color: c,
            ),
          ),
          Positioned(
            right: 8,
            top: 10,
            child: Icon(
              Icons.star_outline_rounded,
              size: 24,
              color: AppColors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 8,
            child: Icon(
              Icons.near_me_outlined,
              size: 26,
              color: AppColors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Icon(
              Icons.change_history_rounded,
              size: 22,
              color: AppColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({
    required this.color,
    this.strokeWidth = 2,
  });
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    const dash = 6.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    var distance = 0.0;
    final circum = 2 * math.pi * r;
    while (distance < circum) {
      final startAngle = (distance / circum) * 2 * math.pi - math.pi / 2;
      final endDist = math.min(distance + dash, circum);
      final sweepAngle = ((endDist - distance) / circum) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      distance = endDist + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });
  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final e = d + dash;
        canvas.drawPath(
          m.extractPath(d, e > m.length ? m.length : e),
          paint,
        );
        d = e + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}
