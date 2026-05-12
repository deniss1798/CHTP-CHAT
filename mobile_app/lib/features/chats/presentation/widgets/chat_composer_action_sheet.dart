import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';

enum ChatComposerAttachmentAction {
  photo,
  videoGallery,
  document,
  poll,
}

enum ChatComposerDesktopExtraAction {
  videoNote,
  voice,
}

class ChatComposerAttachmentSheet extends StatelessWidget {
  const ChatComposerAttachmentSheet({super.key});

  @override
  Widget build(BuildContext context) {
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
                    Icons.attach_file_rounded,
                    color: AppColors.accentBright,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Добавить в чат',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Выберите тип вложения',
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
            _AttachmentChoice(
              icon: AppIcons.photo,
              title: 'Фото',
              subtitle: 'Загрузить изображение с устройства',
              onTap: () =>
                  Navigator.of(context).pop(ChatComposerAttachmentAction.photo),
            ),
            const SizedBox(height: 10),
            _AttachmentChoice(
              icon: AppIcons.videoLibrary,
              title: 'Видео',
              subtitle: 'Выбрать обычное видео из галереи',
              onTap: () => Navigator.of(context)
                  .pop(ChatComposerAttachmentAction.videoGallery),
            ),
            const SizedBox(height: 10),
            _AttachmentChoice(
              icon: Icons.insert_drive_file_rounded,
              title: 'Файл',
              subtitle:
                  'PDF, Office, ODF, RTF, текстовые документы — до 50 МБ',
              onTap: () => Navigator.of(context)
                  .pop(ChatComposerAttachmentAction.document),
            ),
            const SizedBox(height: 10),
            _AttachmentChoice(
              icon: Icons.poll_outlined,
              title: 'Опрос',
              subtitle: 'Создать голосование с несколькими вариантами',
              onTap: () => Navigator.of(context)
                  .pop(ChatComposerAttachmentAction.poll),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: AppColors.textMuted.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Вложения отправляются по защищённому соединению',
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

class _AttachmentChoice extends StatelessWidget {
  const _AttachmentChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                child: Icon(icon, color: AppColors.accentBright, size: 26),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.85),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatComposerDesktopExtraSheet extends StatelessWidget {
  const ChatComposerDesktopExtraSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: AppSurface(
        tone: AppSurfaceTone.elevated,
        radius: AppRadius.xxl,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.videocam, color: AppColors.accent),
              title: const Text('Видеосообщение'),
              onTap: () =>
                  Navigator.of(context).pop(ChatComposerDesktopExtraAction.videoNote),
            ),
            ListTile(
              leading: const Icon(
                Icons.mic_none_rounded,
                color: AppColors.accent,
              ),
              title: const Text('Голосовое'),
              onTap: () =>
                  Navigator.of(context).pop(ChatComposerDesktopExtraAction.voice),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
