import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../chat_detail_formatters.dart';
import 'chat_detail_video_message_widget.dart';

class ChatDetailMessageContent extends StatelessWidget {
  const ChatDetailMessageContent({
    super.key,
    required this.message,
    required this.isMine,
    required this.onOpenFullscreenImage,
    required this.onOpenFullscreenVideo,
  });

  final Map<String, dynamic> message;
  final bool isMine;
  final void Function(String url) onOpenFullscreenImage;
  final void Function(String url, {required bool isVideoNote}) onOpenFullscreenVideo;

  @override
  Widget build(BuildContext context) {
    final messageType = (message['message_type'] ?? 'text').toString();
    final mediaUrl = (message['media_url'] ?? '').toString().trim();

    if (messageType == 'document' && mediaUrl.isNotEmpty) {
      final name = (message['text'] ?? '').toString().trim();
      final sizeLabel = chatDetailFormatDocSize(message['media_size']);
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final uri = Uri.tryParse(mediaUrl);
              if (uri == null) return;
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.black.withAlpha(28)
                    : Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    color: AppColors.accentBright,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name.isEmpty ? 'Файл' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (sizeLabel != null)
                          Text(
                            sizeLabel,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (messageType == 'video_note' && mediaUrl.isNotEmpty) {
      return SizedBox(
        width: 220,
        height: 220,
        child: ChatDetailVideoMessageWidget(
          url: mediaUrl,
          isMine: isMine,
          isVideoNote: true,
        ),
      );
    }

    if (messageType == 'image' && mediaUrl.isNotEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpenFullscreenImage(mediaUrl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 220,
            maxHeight: 280,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 220,
                  height: 220,
                  color: Colors.black.withAlpha(14),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent.withAlpha(220),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) {
                return Container(
                  width: 220,
                  height: 160,
                  color: isMine
                      ? Colors.black.withAlpha(20)
                      : AppColors.surfaceSoft,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Не удалось загрузить фото',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isMine ? Colors.black : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    if (messageType == 'video' && mediaUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 240,
          maxHeight: 280,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ChatDetailVideoMessageWidget(
            url: mediaUrl,
            isMine: isMine,
            isVideoNote: false,
            onOpenFullscreen: () =>
                onOpenFullscreenVideo(mediaUrl, isVideoNote: false),
          ),
        ),
      );
    }

    final plain = (message['text'] ?? '').toString();
    final baseStyle = const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    return SelectionArea(
      child: SelectableLinkify(
        onOpen: (link) async {
          final uri = Uri.tryParse(link.url);
          if (uri == null) return;
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        text: plain,
        style: baseStyle,
        linkStyle: baseStyle.copyWith(
          color: AppColors.accentBright,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.accentBright.withAlpha(200),
        ),
      ),
    );
  }
}
