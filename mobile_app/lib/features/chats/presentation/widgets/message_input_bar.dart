import 'package:flutter/material.dart';

import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart' show AppGradients, AppSizes;
import '../../../../app/widgets/app_surface.dart' show AppIconButtonSurface, AppSurface;
import '../../../../core/platform/desktop_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'attachment_preview.dart';
import 'reply_preview.dart';

/// Нижняя панель: превью ответа/редактирования, вложения, поле ввода, отправка.
class ChatDetailMessageInputBar extends StatelessWidget {
  const ChatDetailMessageInputBar({
    super.key,
    required this.messageController,
    required this.isEditing,
    required this.replyingTo,
    required this.replyAuthorLabel,
    required this.isSending,
    required this.isSendingImage,
    required this.isSendingVideo,
    required this.isSendingDocument,
    required this.isSendingVoice,
    required this.isRecordingVoice,
    required this.onCancelEdit,
    required this.onCancelReply,
    required this.onPickAttachment,
    required this.onVideoNote,
    required this.onVoiceRecordTap,
    required this.onVoicePickFile,
    required this.onSend,
    this.onDesktopExtras,
  });

  final TextEditingController messageController;
  final bool isEditing;
  final Map<String, dynamic>? replyingTo;
  final String replyAuthorLabel;
  final bool isSending;
  final bool isSendingImage;
  final bool isSendingVideo;
  final bool isSendingDocument;
  final bool isSendingVoice;
  final bool isRecordingVoice;
  final VoidCallback onCancelEdit;
  final VoidCallback onCancelReply;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;
  final VoidCallback onVoiceRecordTap;
  final VoidCallback onVoicePickFile;
  final VoidCallback onSend;
  final VoidCallback? onDesktopExtras;

  @override
  Widget build(BuildContext context) {
    final reply = replyingTo;
    final busy =
        isSendingImage || isSendingVideo || isSendingDocument || isSendingVoice;

    final isDesktop = isDesktopMessengerLayout;
    final w = MediaQuery.sizeOf(context).width;
    final mobileStacked = !isDesktop && w < 410;
    final mobileCompact = !isDesktop && w < 560;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          mobileCompact ? 6 : 10,
          mobileCompact ? 6 : 8,
          mobileCompact ? 6 : 10,
          mobileCompact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: AppColors.strokeSoft,
          ),
          boxShadow: AppShadows.topBar,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing) ChatDetailEditModeBanner(onCancel: onCancelEdit),
            if (!isEditing && reply != null)
              ChatDetailReplyPreviewBar(
                reply: reply,
                replyAuthorLabel: replyAuthorLabel,
                onCancel: onCancelReply,
              ),
            if (isDesktop)
              _DesktopMessageComposerRow(
                messageController: messageController,
                isEditing: isEditing,
                isSending: isSending,
                isBusy: busy,
                isRecordingVoice: isRecordingVoice,
                onPickAttachment: onPickAttachment,
                onExtra: onDesktopExtras ?? onPickAttachment,
                onSend: onSend,
              )
            else if (mobileStacked)
              _MobileStackedComposer(
                messageController: messageController,
                isEditing: isEditing,
                isSending: isSending,
                isBusy: busy,
                isRecordingVoice: isRecordingVoice,
                onPickAttachment: onPickAttachment,
                onVideoNote: onVideoNote,
                onVoiceRecordTap: onVoiceRecordTap,
                onVoicePickFile: onVoicePickFile,
                onSend: onSend,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ChatDetailAttachmentPreview(
                    isEditing: isEditing,
                    isBusy: busy,
                    isRecordingVoice: isRecordingVoice,
                    onPickAttachment: onPickAttachment,
                    onVideoNote: onVideoNote,
                    onVoiceRecordTap: onVoiceRecordTap,
                    onVoicePickFile: onVoicePickFile,
                    compact: mobileCompact,
                  ),
                  Expanded(
                    child: AppSurface(
                      radius: AppRadius.pill,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      borderColor: AppColors.strokeSoft,
                      shadow: const [],
                      child: TextField(
                        controller: messageController,
                        style: AppTextStyles.input,
                        minLines: 1,
                        maxLines: mobileCompact ? 4 : 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: isEditing
                              ? 'Новый текст сообщения...'
                              : 'Введите сообщение...',
                          hintStyle: AppTextStyles.inputHint,
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: mobileCompact ? 12 : 16,
                            vertical: mobileCompact ? 10 : 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: mobileCompact ? 6 : 10),
                  _SendButton(
                    isEditing: isEditing,
                    isSending: isSending,
                    onSend: onSend,
                    diameter: mobileCompact ? 46 : AppSizes.fab - 6,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEditing,
    required this.isSending,
    required this.onSend,
    required this.diameter,
  });

  final bool isEditing;
  final bool isSending;
  final VoidCallback onSend;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final iconSize = diameter >= 50 ? AppSizes.iconLg : 22.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSending ? null : onSend,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            gradient: AppGradients.accentPanel,
            shape: BoxShape.circle,
            boxShadow: AppShadows.accentFab(),
          ),
          child: Center(
            child: isSending
                ? SizedBox(
                    width: diameter * 0.4,
                    height: diameter * 0.4,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textOnAccent,
                      ),
                    ),
                  )
                : Icon(
                    isEditing ? AppIcons.check : AppIcons.send,
                    color: AppColors.textOnAccent,
                    size: iconSize,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MobileStackedComposer extends StatelessWidget {
  const _MobileStackedComposer({
    required this.messageController,
    required this.isEditing,
    required this.isSending,
    required this.isBusy,
    required this.isRecordingVoice,
    required this.onPickAttachment,
    required this.onVideoNote,
    required this.onVoiceRecordTap,
    required this.onVoicePickFile,
    required this.onSend,
  });

  final TextEditingController messageController;
  final bool isEditing;
  final bool isSending;
  final bool isBusy;
  final bool isRecordingVoice;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;
  final VoidCallback onVoiceRecordTap;
  final VoidCallback onVoicePickFile;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppSurface(
                radius: AppRadius.xl,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                shadow: AppShadows.lift,
                child: TextField(
                  controller: messageController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: isEditing
                        ? 'Новый текст сообщения...'
                        : 'Введите сообщение...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(
              isEditing: isEditing,
              isSending: isSending,
              onSend: onSend,
              diameter: 46,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ChatDetailAttachmentPreview(
              isEditing: isEditing,
              isBusy: isBusy,
              isRecordingVoice: isRecordingVoice,
              onPickAttachment: onPickAttachment,
              onVideoNote: onVideoNote,
              onVoiceRecordTap: onVoiceRecordTap,
              onVoicePickFile: onVoicePickFile,
              compact: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopMessageComposerRow extends StatelessWidget {
  const _DesktopMessageComposerRow({
    required this.messageController,
    required this.isEditing,
    required this.isSending,
    required this.isBusy,
    required this.isRecordingVoice,
    required this.onPickAttachment,
    required this.onExtra,
    required this.onSend,
  });

  final TextEditingController messageController;
  final bool isEditing;
  final bool isSending;
  final bool isBusy;
  final bool isRecordingVoice;
  final VoidCallback onPickAttachment;
  final VoidCallback onExtra;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButtonSurface(
          icon: Icons.attach_file_rounded,
          tooltip: 'Вложение',
          onTap: (isEditing || (isBusy && !isRecordingVoice)) ? null : onPickAttachment,
        ),
        const SizedBox(width: 2),
        AppIconButtonSurface(
          icon: Icons.mood_rounded,
          tooltip: 'Эмодзи',
          onTap: (isEditing || isBusy) ? null : () {},
        ),
        const SizedBox(width: 2),
        AppIconButtonSurface(
          icon: Icons.add_rounded,
          tooltip: 'Дополнительно',
          onTap: (isEditing || (isBusy && !isRecordingVoice)) ? null : onExtra,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppSurface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            shadow: AppShadows.lift,
            child: TextField(
              controller: messageController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: isEditing
                    ? 'Новый текст сообщения...'
                    : 'Введите сообщение...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSending ? null : onSend,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppGradients.accentPanel,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.accentFab(),
              ),
              child: Center(
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textOnAccent,
                          ),
                        ),
                      )
                    : Icon(
                        isEditing ? AppIcons.check : AppIcons.send,
                        color: AppColors.textOnAccent,
                        size: AppSizes.iconLg,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
