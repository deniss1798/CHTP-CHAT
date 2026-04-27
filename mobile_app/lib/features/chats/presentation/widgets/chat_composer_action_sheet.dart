import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';

enum ChatComposerAttachmentAction {
  photo,
  videoGallery,
  document,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.photo, color: AppColors.accent),
              title: const Text('Photo'),
              onTap: () =>
                  Navigator.of(context).pop(ChatComposerAttachmentAction.photo),
            ),
            ListTile(
              leading: const Icon(
                AppIcons.videoLibrary,
                color: AppColors.accent,
              ),
              title: const Text('Video'),
              subtitle: const Text('Pick a regular video from gallery'),
              onTap: () => Navigator.of(context)
                  .pop(ChatComposerAttachmentAction.videoGallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: AppColors.accent,
              ),
              title: const Text('File'),
              subtitle: const Text('PDF, Office, ODF, RTF, TXT up to 50 MB'),
              onTap: () => Navigator.of(context)
                  .pop(ChatComposerAttachmentAction.document),
            ),
            const SizedBox(height: 4),
          ],
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
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
