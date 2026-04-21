import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
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
  final void Function(String url, {required bool isVideoNote})
      onOpenFullscreenVideo;

  @override
  Widget build(BuildContext context) {
    final messageType = (message['message_type'] ?? 'text').toString();
    final mediaUrl = (message['media_url'] ?? '').toString().trim();

    if (messageType == 'voice' && mediaUrl.isNotEmpty) {
      return _VoiceMessageBar(url: mediaUrl);
    }

    if (messageType == 'document' && mediaUrl.isNotEmpty) {
      return _buildDocumentCard(mediaUrl);
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
            maxWidth: 260,
            maxHeight: 360,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return ColoredBox(
                    color: AppColors.surfaceSoft,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textMuted.withAlpha(200),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: AppColors.surfaceSoft,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Не удалось загрузить фото',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    if (messageType == 'video' && mediaUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 260,
          maxHeight: 320,
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

  Widget _buildDocumentCard(String mediaUrl) {
    final name = (message['text'] ?? '').toString().trim();
    final sizeLabel = chatDetailFormatDocSize(message['media_size']);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 292),
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
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isMine
                  ? AppColors.surfaceHighlight
                  : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.strokeSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
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
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _VoiceMessageBar extends StatefulWidget {
  const _VoiceMessageBar({
    required this.url,
  });

  final String url;

  @override
  State<_VoiceMessageBar> createState() => _VoiceMessageBarState();
}

class _VoiceMessageBarState extends State<_VoiceMessageBar> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((PlayerState s) {
      if (mounted) {
        setState(() => _playerState = s);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playerState == PlayerState.playing) {
      await _player.stop();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(
            _playerState == PlayerState.playing
                ? Icons.stop_rounded
                : Icons.play_arrow_rounded,
            color: AppColors.textPrimary,
            size: 28,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Голосовое',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

