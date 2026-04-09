import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/services/chats_service.dart';

class GroupMembersManageScreen extends StatefulWidget {
  const GroupMembersManageScreen({
    super.key,
    required this.chatId,
    required this.createdBy,
    required this.currentUserId,
  });

  final int chatId;
  final int createdBy;
  final int currentUserId;

  @override
  State<GroupMembersManageScreen> createState() =>
      _GroupMembersManageScreenState();
}

class _GroupMembersManageScreenState extends State<GroupMembersManageScreen> {
  final ChatsService _chatsService = ChatsService();
  final Dio _dio = ApiClient.dio;

  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await SecureStorageService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Токен не найден');
      }
      final response = await _dio.get(
        '/chats/${widget.chatId}/members',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final list = <Map<String, dynamic>>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _members = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить участников';
        _loading = false;
      });
    }
  }

  bool get _isCreator => widget.createdBy == widget.currentUserId;

  Future<void> _remove(int userId, String username) async {
    if (!_isCreator || userId == widget.currentUserId) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Удалить из группы?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Удалить $username из группы?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _chatsService.removeGroupMember(
        chatId: widget.chatId,
        memberUserId: userId,
      );
      if (!mounted) return;
      setState(() {
        _members.removeWhere((m) {
          final id = _parseId(m['id']);
          return id == userId;
        });
        _busy = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$username удалён из группы')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      String msg = 'Не удалось удалить';
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map) {
          msg = d['detail']?.toString() ?? msg;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _avatarUrl(Map<String, dynamic> m) {
    final raw = (m['avatar_url'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    return '${ApiClient.baseUrl}$raw';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Участники',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isCreator)
                const Padding(
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 8),
                  child: Text(
                    'Только создатель группы может удалять участников.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _members.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final m = _members[index];
                              final uid = _parseId(m['id']);
                              final username =
                                  (m['username'] ?? 'Пользователь').toString();
                              final email = (m['email'] ?? '').toString();
                              final avatar = _avatarUrl(m);
                              final canRemove = _isCreator &&
                                  uid != null &&
                                  uid != widget.currentUserId &&
                                  !_busy;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withAlpha(210),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color:
                                        AppColors.accentBorder.withAlpha(110),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildAvatar(avatar, username),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            username,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (canRemove)
                                      IconButton(
                                        onPressed: () =>
                                            _remove(uid, username),
                                        icon: const Icon(
                                          Icons.person_remove_outlined,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String url, String title) {
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(title),
        ),
      );
    }
    return _fallback(title);
  }

  Widget _fallback(String title) {
    final ch = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
