import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
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
    this.compact = false,
  });

  final bool isEditing;
  final bool isBusy;
  final bool isRecordingVoice;
  /// Узкий экран: меньше кнопки и отступы.
  final bool compact;
  final VoidCallback onPickAttachment;
  final VoidCallback onVideoNote;
  final VoidCallback onVoiceRecordTap;
  final VoidCallback onVoicePickFile;

  @override
  Widget build(BuildContext context) {
    final blockMedia = isEditing || isBusy || isRecordingVoice;
    final blockMic =
        isEditing || (isBusy && !isRecordingVoice);

    final btn = compact ? 36.0 : AppSizes.topAction;
    final gap = compact ? 4.0 : 6.0;
    final ic = compact ? AppSizes.iconSm : AppSizes.iconMd;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Фото, видео или файл',
          child: AppIconButtonSurface(
            icon: AppIcons.permMedia,
            size: btn,
            iconSize: ic,
            tooltip: 'Медиа',
            onTap: blockMedia ? null : onPickAttachment,
            iconColor: isEditing ? AppColors.textMuted : AppColors.accentBright,
          ),
        ),
        SizedBox(width: gap),
        Tooltip(
          message: 'Видеосообщение (кружок) — удерживайте кнопку записи',
          child: AppIconButtonSurface(
            icon: AppIcons.videocam,
            size: btn,
            iconSize: ic,
            tooltip: 'Видеосообщение',
            onTap: blockMedia ? null : onVideoNote,
            iconColor: isEditing ? AppColors.textMuted : AppColors.accentBright,
          ),
        ),
        SizedBox(width: gap),
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
              size: btn,
              iconSize: ic,
              tooltip: 'Голосовое',
              onTap: blockMic ? null : onVoiceRecordTap,
              iconColor: isRecordingVoice
                  ? Colors.redAccent
                  : (isEditing ? AppColors.textMuted : AppColors.accentBright),
            ),
          ),
        ),
        SizedBox(width: compact ? 4 : 8),
      ],
    );
  }
}
