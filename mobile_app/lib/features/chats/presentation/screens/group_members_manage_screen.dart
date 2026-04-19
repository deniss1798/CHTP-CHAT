import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../data/models/chat_models.dart';
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

  List<ChatMember> _members = [];
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
      final list = await _chatsService.fetchChatMembers(widget.chatId);
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
        _members.removeWhere((member) => member.id == userId);
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
      var msg = 'Не удалось удалить';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          msg = data['detail']?.toString() ?? msg;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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
                      AppIcons.back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Участники',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
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
                              final member = _members[index];
                              final username = member.username;
                              final email = member.email ?? '';
                              final avatar = member.avatarUrl ?? '';
                              final canRemove = _isCreator &&
                                  member.id != widget.currentUserId &&
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
                                        onPressed: () => _remove(
                                          member.id,
                                          username,
                                        ),
                                        icon: const Icon(
                                          AppIcons.personRemove,
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
