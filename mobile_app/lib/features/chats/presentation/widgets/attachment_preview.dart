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
    required this.isRecordingVoice,
    required this.onPickAttachment,
    required this.onVideoNote,
    required this.onVoiceRecordTap,
    required this.onVoicePickFile,
  });

  final bool isEditing;
  final bool isBusy;
  final bool isRecordingVoice;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;
  final VoidCallback onVoiceRecordTap;
  final VoidCallback onVoicePickFile;

  @override
  Widget build(BuildContext context) {
    final blockMedia = isEditing || isBusy || isRecordingVoice;
    final blockMic =
        isEditing || (isBusy && !isRecordingVoice);

    return Row(
      children: [
        Tooltip(
          message: 'Фото, видео или файл',
          child: AppIconButtonSurface(
            icon: AppIcons.permMedia,
            tooltip: 'Медиа',
            onTap: blockMedia ? null : onPickAttachment,
            iconColor: isEditing ? AppColors.textMuted : AppColors.accentBright,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Видеосообщение (кружок) — удерживайте кнопку записи',
          child: AppIconButtonSurface(
            icon: AppIcons.videocam,
            tooltip: 'Видеосообщение',
            onTap: blockMedia ? null : onVideoNote,
            iconColor: isEditing ? AppColors.textMuted : AppColors.accentBright,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: isRecordingVoice
              ? 'Нажмите ещё раз — остановить и отправить'
              : 'Запись: нажмите для старта/стопа. Долгое нажатие — файл с диска.',
          child: GestureDetector(
            onLongPress:
                (isRecordingVoice || isEditing || (isBusy && !isRecordingVoice))
                    ? null
                    : onVoicePickFile,
            child: AppIconButtonSurface(
              icon: isRecordingVoice ? Icons.mic_rounded : Icons.mic_none_rounded,
              tooltip: 'Голосовое',
              onTap: blockMic ? null : onVoiceRecordTap,
              iconColor: isRecordingVoice
                  ? Colors.redAccent
                  : (isEditing ? AppColors.textMuted : AppColors.accentBright),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
