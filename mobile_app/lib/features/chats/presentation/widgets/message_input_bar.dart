import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/theme/app_shadows.dart';
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
    required this.onCancelEdit,
    required this.onCancelReply,
    required this.onPickAttachment,
    required this.onVideoNote,
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
  final VoidCallback onCancelEdit;
  final VoidCallback onCancelReply;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final reply = replyingTo;
    final busy = isSendingImage || isSendingVideo || isSendingDocument;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(
              color: Colors.white.withAlpha(10),
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
                  onPickAttachment: onPickAttachment,
                  onVideoNote: onVideoNote,
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: isEditing
                          ? 'Новый текст сообщения...'
                          : 'Введите сообщение...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceSoft,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: isSending ? null : onSend,
                  child: Container(
                    width: AppSizes.fab - 8,
                    height: AppSizes.fab - 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.primaryButton,
                    ),
                    alignment: Alignment.center,
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Icon(
                            isEditing ? AppIcons.check : AppIcons.send,
                            color: Colors.black,
                            size: AppSizes.iconMd,
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
