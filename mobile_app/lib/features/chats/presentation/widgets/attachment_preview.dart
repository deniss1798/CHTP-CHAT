import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/theme/app_shadows.dart';

/// Кнопки вложений (галерея / видеосообщение) над строкой ввода.
class ChatDetailAttachmentPreview extends StatelessWidget {
  const ChatDetailAttachmentPreview({
    super.key,
    required this.isEditing,
    required this.isBusy,
    required this.onPickAttachment,
    required this.onVideoNote,
  });

  final bool isEditing;
  final bool isBusy;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Фото, видео или файл',
          child: GestureDetector(
            onTap: (isEditing || isBusy) ? null : onPickAttachment,
            child: Container(
              width: AppSizes.inputAction,
              height: AppSizes.inputAction,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: Colors.white.withAlpha(10)),
                boxShadow: AppShadows.lift,
              ),
              alignment: Alignment.center,
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      AppIcons.permMedia,
                      color: isEditing ? AppColors.textMuted : AppColors.accentBright,
                      size: AppSizes.iconMd,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Видеосообщение (кружок) — удерживайте кнопку записи',
          child: GestureDetector(
            onTap: (isEditing || isBusy) ? null : onVideoNote,
            child: Container(
              width: AppSizes.inputAction,
              height: AppSizes.inputAction,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: Colors.white.withAlpha(10)),
                boxShadow: AppShadows.lift,
              ),
              alignment: Alignment.center,
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      AppIcons.videocam,
                      color: isEditing ? AppColors.textMuted : AppColors.accentBright,
                      size: AppSizes.iconMd,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
