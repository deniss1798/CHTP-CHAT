import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ChatPinnedMessagesBanner extends StatelessWidget {
  const ChatPinnedMessagesBanner({
    super.key,
    required this.messages,
    required this.currentIndex,
    required this.onTap,
    required this.onUnpin,
    this.onCycle,
  });

  final List<Map<String, dynamic>> messages;
  final int currentIndex;
  final VoidCallback onTap;
  final VoidCallback onUnpin;
  final VoidCallback? onCycle;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final safeIndex = currentIndex.clamp(0, messages.length - 1);
    final m = messages[safeIndex];
    final mt = (m['message_type'] ?? 'text').toString();
    final text = (m['text'] ?? '').toString().trim();
    final preview = _previewFor(mt, text);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (messages.length > 1 && onCycle != null) {
            onCycle!();
          }
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            border: Border(
              bottom: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.18),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.push_pin,
                color: AppColors.accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      messages.length > 1
                          ? 'Закреплённое ${safeIndex + 1}/${messages.length}'
                          : 'Закреплённое сообщение',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Открепить',
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: onUnpin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewFor(String mt, String text) {
    switch (mt) {
      case 'image':
        return text.isNotEmpty ? text : 'Фото';
      case 'video':
        return text.isNotEmpty ? text : 'Видео';
      case 'video_note':
        return 'Видеосообщение';
      case 'voice':
        return 'Голосовое сообщение';
      case 'document':
      case 'file':
        return text.isNotEmpty ? text : 'Файл';
      case 'poll':
        return text.isNotEmpty ? text : 'Опрос';
      default:
        return text.isNotEmpty ? text : 'Сообщение';
    }
  }
}
