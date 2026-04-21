import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/widgets/app_surface.dart';
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

  @override
  Widget build(BuildContext context) {
    final reply = replyingTo;
    final busy =
        isSendingImage || isSendingVideo || isSendingDocument || isSendingVoice;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.background.withAlpha(235),
          border: Border(
            top: BorderSide(
              color: AppColors.strokeSoft,
            ),
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
            Row(
              children: [
                ChatDetailAttachmentPreview(
                  isEditing: isEditing,
                  isBusy: busy,
                  isRecordingVoice: isRecordingVoice,
                  onPickAttachment: onPickAttachment,
                  onVideoNote: onVideoNote,
                  onVoiceRecordTap: onVoiceRecordTap,
                  onVoicePickFile: onVoicePickFile,
                ),
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
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isSending ? null : onSend,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Ink(
                      width: AppSizes.fab - 6,
                      height: AppSizes.fab - 6,
                      decoration: BoxDecoration(
                        gradient: AppGradients.accentPanel,
                        shape: BoxShape.circle,
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
            ),
          ],
        ),
      ),
    );
  }
}
