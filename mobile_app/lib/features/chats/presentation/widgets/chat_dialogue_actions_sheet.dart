import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';
import '../controller/chats_controller.dart';
import '../models/chat_list_item_model.dart';
import '../models/chats_list_filter.dart';

String _shortSnack(String message) {
  final t = message.trim();
  if (t.length <= 180) return t;
  return '${t.substring(0, 177)}…';
}

/// Нижняя шторка действий над диалогом (архив / закрепление / уведомления).
/// Визуально в одном стиле с [ChatComposerAttachmentSheet].
Future<void> showChatDialogueActionsSheet({
  required BuildContext context,
  required ChatsController controller,
  required ChatListItemModel initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (ctx) {
      return _ChatDialogueActionsSheetInner(
        controller: controller,
        initial: initial,
      );
    },
  );
}

class _ChatDialogueActionsSheetInner extends StatefulWidget {
  const _ChatDialogueActionsSheetInner({
    required this.controller,
    required this.initial,
  });

  final ChatsController controller;
  final ChatListItemModel initial;

  @override
  State<_ChatDialogueActionsSheetInner> createState() =>
      _ChatDialogueActionsSheetInnerState();
}

class _ChatDialogueActionsSheetInnerState
    extends State<_ChatDialogueActionsSheetInner> {
  late bool archived;
  late bool muted;
  late bool pinned;
  bool workingArchive = false;
  bool workingMute = false;
  bool workingPin = false;

  @override
  void initState() {
    super.initState();
    archived = widget.initial.isArchived;
    muted = widget.initial.notificationsMuted;
    pinned = widget.initial.isPinned;
  }

  Future<void> _onPin() async {
    if (workingArchive || workingMute || workingPin) return;
    final nextPinned = !pinned;
    setState(() => workingPin = true);
    final err = await widget.controller.patchMemberPreferences(
      chatId: widget.initial.chatId,
      isPinned: nextPinned,
    );
    if (!mounted) return;
    setState(() => workingPin = false);
    if (err != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(_shortSnack(err))),
      );
      return;
    }
    setState(() => pinned = nextPinned);
  }

  Future<void> _onArchive() async {
    if (workingArchive || workingMute || workingPin) return;
    final nextArchived = !archived;
    setState(() => workingArchive = true);
    final err = await widget.controller.patchMemberPreferences(
      chatId: widget.initial.chatId,
      isArchived: nextArchived,
    );
    if (!mounted) return;
    setState(() => workingArchive = false);
    if (err != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(_shortSnack(err))),
      );
      return;
    }

    setState(() {
      archived = nextArchived;
      if (nextArchived) {
        pinned = false;
      }
    });

    final tab = widget.controller.state.listFilter;
    final leaveList = (tab != ChatsListFilter.archive && nextArchived) ||
        (tab == ChatsListFilter.archive && !nextArchived);
    if (leaveList && mounted) Navigator.of(context).maybePop();
  }

  Future<void> _onMute() async {
    if (workingArchive || workingMute || workingPin) return;
    final nextMuted = !muted;
    setState(() => workingMute = true);
    final err = await widget.controller.patchMemberPreferences(
      chatId: widget.initial.chatId,
      notificationsMuted: nextMuted,
    );
    if (!mounted) return;
    setState(() => workingMute = false);
    if (err != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(_shortSnack(err))),
      );
      return;
    }
    setState(() => muted = nextMuted);
  }

  String get _archiveTitle => archived ? 'Вернуть из архива' : 'В архив';
  String get _archiveSubtitle => archived
      ? 'Чат снова появится в основном списке.'
      : 'Скрыть чат из основного списка.';

  String get _pinTitle => pinned ? 'Открепить' : 'Закрепить';
  String get _pinSubtitle => pinned
      ? 'Убрать из закреплённых сверху списка.'
      : 'Показывать рядом с другими закреплёнными чатами.';

  String get _muteTitle => muted ? 'Включить уведомления' : 'Отключить уведомления';
  String get _muteSubtitle => muted
      ? 'Снова получать push и отображать на экране блокировки.'
      : 'Без звука и без всплывающих уведомлений по этому чату.';

  @override
  Widget build(BuildContext context) {
    final title = widget.initial.title.trim().isEmpty
        ? 'Чат'
        : widget.initial.title;

    final actionsDisabled =
        workingArchive || workingMute || workingPin;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: AppSurface(
        tone: AppSurfaceTone.elevated,
        radius: AppRadius.xxl,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentBright.withValues(alpha: 0.35),
                        AppColors.accent.withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.accentBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: AppColors.accentBright,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.2,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Архив, закрепление и уведомления',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.95),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogueActionRow(
              icon: archived ? Icons.unarchive_rounded : Icons.archive_rounded,
              title: _archiveTitle,
              subtitle: _archiveSubtitle,
              busy: workingArchive,
              enabled: !actionsDisabled || workingArchive,
              onTap: _onArchive,
            ),
            const SizedBox(height: 10),
            _DialogueActionRow(
              icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
              title: _pinTitle,
              subtitle: _pinSubtitle,
              busy: workingPin,
              enabled: !actionsDisabled || workingPin,
              onTap: _onPin,
            ),
            const SizedBox(height: 10),
            _DialogueActionRow(
              icon: muted
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              title: _muteTitle,
              subtitle: _muteSubtitle,
              busy: workingMute,
              enabled: !actionsDisabled || workingMute,
              onTap: _onMute,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 15,
                  color: AppColors.textMuted.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Настройки сохраняются на сервере и доступны со всех устройств.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.textMuted.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogueActionRow extends StatelessWidget {
  const _DialogueActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effective = enabled && !busy;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effective ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md + 4),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md + 4),
            color: AppColors.surface.withValues(alpha: 0.92),
            border: Border.all(
              color: AppColors.strokeAccent.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.accentBright,
                          ),
                        )
                      : Icon(
                          icon,
                          color: effective
                              ? AppColors.accentBright
                              : AppColors.textMuted,
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: effective
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(
                          alpha: effective ? 0.95 : 0.55,
                        ),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 24)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted.withValues(
                    alpha: effective ? 0.85 : 0.4,
                  ),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
