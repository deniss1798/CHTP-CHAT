import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../data/models/chat_models.dart';
import 'chat_detail_avatar_widgets.dart';

/// Текстовые кнопки внизу справа: оранжевый акцент, как в макетах «ЧТП ЧАТ».
class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: Text(
                cancelLabel,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: onConfirm,
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Подтверждение с опциональным «контекстом» (аватар + подпись) сверху.
Future<bool> showMessengerConfirmDialog({
  required BuildContext context,
  required String title,
  String? body,
  String cancelLabel = 'Отмена',
  String confirmLabel = 'Удалить',
  Widget? contextHeader,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AppSurface(
            tone: AppSurfaceTone.elevated,
            radius: AppRadius.xl,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            borderColor: AppColors.strokeSoft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (contextHeader != null) ...[
                  contextHeader,
                  const SizedBox(height: 12),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _DialogActions(
                  cancelLabel: cancelLabel,
                  confirmLabel: confirmLabel,
                  onCancel: () => Navigator.of(ctx).pop(false),
                  onConfirm: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return r == true;
}

class _GroupRenameDialogBody extends StatefulWidget {
  const _GroupRenameDialogBody({
    required this.initialTitle,
    required this.groupTitleForInitials,
    this.avatarUrl,
  });

  final String initialTitle;
  final String groupTitleForInitials;
  final String? avatarUrl;

  @override
  State<_GroupRenameDialogBody> createState() => _GroupRenameDialogBodyState();
}

class _GroupRenameDialogBodyState extends State<_GroupRenameDialogBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AppSurface(
        tone: AppSurfaceTone.elevated,
        radius: AppRadius.xxl,
        padding: const EdgeInsets.fromLTRB(22, 20, 18, 16),
        borderColor: AppColors.accent.withValues(alpha: 0.22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ChatDetailSquareAvatar(
                title: widget.groupTitleForInitials,
                avatarUrl: widget.avatarUrl,
                size: 56,
                showOnlineDot: false,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Название группы',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(
                    color: AppColors.accentBright,
                    width: 1.45,
                  ),
                ),
                hintText: 'Название',
                hintStyle: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            _DialogActions(
              cancelLabel: 'Отмена',
              confirmLabel: 'Сохранить',
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () {
                final t = _controller.text.trim();
                Navigator.of(context).pop(t.isEmpty ? null : t);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Переименование группы: аватар, заголовок, поле с оранжевой обводкой.
Future<String?> showMessengerGroupRenameDialog({
  required BuildContext context,
  required String initialTitle,
  required String groupTitleForInitials,
  String? avatarUrl,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _GroupRenameDialogBody(
          initialTitle: initialTitle,
          groupTitleForInitials: groupTitleForInitials,
          avatarUrl: avatarUrl,
        ),
      );
    },
  );
}

/// Нижняя панель «Переслать в…» с аватарами чатов.
Future<ChatSummary?> showForwardChatPickerSheet({
  required BuildContext context,
  required List<ChatSummary> chats,
  int? excludeChatId,
}) {
  final items = excludeChatId == null
      ? chats
      : chats.where((c) => c.id != excludeChatId).toList();

  return showModalBottomSheet<ChatSummary>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      if (items.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          child: AppSurface(
            tone: AppSurfaceTone.elevated,
            radius: AppRadius.xxl,
            padding: const EdgeInsets.all(20),
            borderColor: AppColors.accent.withValues(alpha: 0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Нет других чатов для пересылки',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: AppSurface(
          tone: AppSurfaceTone.elevated,
          radius: AppRadius.xxl,
          borderColor: AppColors.accent.withValues(alpha: 0.22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.forward_rounded,
                      size: 20,
                      color: AppColors.accent.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Переслать в…',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (h * 0.55).clamp(200.0, 520.0),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    indent: 72,
                    color: AppColors.strokeSoft,
                  ),
                  itemBuilder: (context, index) {
                    final chat = items[index];
                    final title = chat.title.trim().isNotEmpty
                        ? chat.title.trim()
                        : 'Чат ${chat.id}';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: ChatDetailSquareAvatar(
                        title: title,
                        avatarUrl: chat.avatarUrl,
                        size: 46,
                        showOnlineDot: false,
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(chat),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
