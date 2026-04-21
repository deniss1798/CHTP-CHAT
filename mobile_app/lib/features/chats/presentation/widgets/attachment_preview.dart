import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/widgets/app_surface.dart';

/// Кнопки вложений (галерея / видеосообщение) над строкой ввода.
class ChatDetailAttachmentPreview extends StatelessWidget {
  const ChatDetailAttachmentPreview({
    super.key,
    required this.isEditing,
    required this.isBusy,
    required this.onPickAttachment,
    required this.onVideoNote,
    required this.onPickVoice,
  });

  final bool isEditing;
  final bool isBusy;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;
  final VoidCallback onPickVoice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Фото, видео или файл',
          child: AppIconButtonSurface(
            icon: AppIcons.permMedia,
            tooltip: 'Медиа',
            onTap: (isEditing || isBusy) ? null : onPickAttachment,
            iconColor: isEditing ? AppColors.textMuted : AppColors.accentBright,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Видеосообщение (кружок) — удерживайте кнопку записи',
          child: AppIconButtonSurface(
            icon: AppIcons.videocam,
            tooltip: 'Видеосообщение',
            onTap: (isEditing || isBusy) ? null : onVideoNote,
            iconColor: isEditing ? AppColors.textMuted : AppColors.accentBright,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Голосовое (выберите аудиофайл)',
          child: AppIconButtonSurface(
            icon: Icons.mic_none_rounded,
            tooltip: 'Голосовое',
            onTap: (isEditing || isBusy) ? null : onPickVoice,
            iconColor: isEditing ? AppColors.textMuted : AppColors.accentBright,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
