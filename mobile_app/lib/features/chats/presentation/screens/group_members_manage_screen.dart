import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_content_frame.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chats_service.dart';
import '../widgets/chat_detail_avatar_widgets.dart';
import '../widgets/messenger_styled_dialogs.dart';

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

String _ruParticipantsWord(int n) {
  final m100 = n % 100;
  final m10 = n % 10;
  if (m10 == 1 && m100 != 11) return 'участник';
  if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 > 20)) {
    return 'участника';
  }
  return 'участников';
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

  Future<void> _remove(
    int userId,
    String username, {
    String? avatarUrl,
  }) async {
    if (!_isCreator || userId == widget.currentUserId) return;
    final ok = await showMessengerConfirmDialog(
      context: context,
      title: 'Удалить из группы?',
      body: 'Удалить $username из группы?',
      confirmLabel: 'Удалить',
      contextHeader: Center(
        child: ChatDetailSquareAvatar(
          title: username,
          avatarUrl: avatarUrl,
          size: 48,
          showOnlineDot: false,
        ),
      ),
    );
    if (!ok || !mounted) return;

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
    final count = _members.length;
    final sub = '$count ${_ruParticipantsWord(count)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppContentFrame(
                maxWidth: AppBreakpoints.wideLayoutMinWidth,
                padding: const EdgeInsets.fromLTRB(8, 10, 20, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconButtonSurface(
                      icon: AppIcons.back,
                      tooltip: 'Назад',
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Участники',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.9,
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isCreator)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                        : AppContentFrame(
                            maxWidth: AppBreakpoints.wideLayoutMinWidth,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                4,
                                0,
                                4,
                                24,
                              ),
                              itemCount: _members.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final member = _members[index];
                                final username = member.username;
                                final email = member.email ?? '';
                                final avatar = member.avatarUrl ?? '';
                                final canRemove = _isCreator &&
                                    member.id != widget.currentUserId &&
                                    !_busy;

                                return AppSurface(
                                  tone: AppSurfaceTone.elevated,
                                  radius: AppRadius.xl,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  shadow: AppShadows.lift,
                                  child: Row(
                                    children: [
                                      _buildAvatar(avatar, username),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              username,
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                height: 1.25,
                                              ),
                                            ),
                                            if (email.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                email,
                                                style: TextStyle(
                                                  color: AppColors
                                                      .textSecondary
                                                      .withValues(
                                                    alpha: 0.95,
                                                  ),
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (canRemove)
                                        IconButton(
                                          tooltip: 'Исключить',
                                          onPressed: () => _remove(
                                            member.id,
                                            username,
                                            avatarUrl: member.avatarUrl,
                                          ),
                                          icon: const Icon(
                                            AppIcons.personRemove,
                                            color: AppColors.accent,
                                            size: 24,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
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
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(title),
        ),
      );
    }
    return _fallback(title);
  }

  Widget _fallback(String title) {
    final ch = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppGradients.accentPanel,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.primaryButton,
      ),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: const TextStyle(
          color: AppColors.textOnAccent,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
