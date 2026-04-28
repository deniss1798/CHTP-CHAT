import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../controller/chats_controller.dart';
import '../models/chat_list_item_model.dart';
import '../models/chats_list_filter.dart';

String _shortSnack(String message) {
  final t = message.trim();
  if (t.length <= 180) return t;
  return '${t.substring(0, 177)}…';
}

/// Нижняя шторка действий над диалогом (архив / закрепление / уведомления), в духе Telegram.
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.strokeSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initial.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 26,
              thickness: 0.5,
              color: AppColors.strokeMedium.withValues(alpha: 0.65),
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
            _SheetAction(
              enabled: !workingArchive && !workingMute && !workingPin,
              busy: workingArchive,
              icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              label:
                  archived ? 'Вернуть из архива' : 'В архив',
              onTap: _onArchive,
            ),
            _SheetAction(
              enabled: !workingArchive && !workingMute && !workingPin,
              busy: workingPin,
              icon: pinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              label:
                  pinned ? 'Открепить' : 'Закрепить',
              onTap: _onPin,
            ),
            _SheetAction(
              enabled: !workingArchive && !workingMute && !workingPin,
              busy: workingMute,
              icon: muted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              label:
                  muted ? 'Включить уведомления' : 'Отключить уведомления',
              onTap: _onMute,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.enabled,
    required this.busy,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effective = enabled && !busy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effective ? onTap : null,
        splashColor: AppColors.accent.withValues(alpha: 0.12),
        highlightColor: AppColors.surfaceHighlight.withValues(alpha: 0.35),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          child: SizedBox(
            height: AppSizes.btnSmHeight + 2,
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.accent,
                            ),
                          )
                        : Icon(
                            icon,
                            size: AppSizes.iconLg + 2,
                            color: effective
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: effective
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
