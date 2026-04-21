import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../chat_detail_message_maps.dart';

/// Быстрые реакции — верхняя полоса как в Telegram.
const List<String> kDefaultQuickReactionEmojis = [
  '👍',
  '❤️',
  '🔥',
  '😁',
  '😢',
  '🙏',
  '💯',
];

/// Один тап по сообщению на телефоне / узком вебе открывает меню; на десктопе — только ПКМ.
bool primaryTapOpensMessageMenu(BuildContext context) {
  if (kIsWeb) {
    return MediaQuery.sizeOf(context).shortestSide < 600;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Панель действий: полоса реакций + разделитель + пункты меню (как в Telegram).
class ChatMessageActionsPanel extends StatelessWidget {
  const ChatMessageActionsPanel({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.onAction,
  });

  final Map<String, dynamic> message;
  final int? currentUserId;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final senderId = ChatDetailMessageMaps.intFromDynamic(message['sender_id']);
    final isMine =
        currentUserId != null && senderId != null && senderId == currentUserId;

    final messageType = (message['message_type'] ?? 'text').toString();
    final text = (message['text'] ?? '').toString().trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in kDefaultQuickReactionEmojis) ...[
                  Material(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: () => onAction('react:$e'),
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        _tile(
          icon: AppIcons.reply,
          label: 'Ответить',
          onTap: () => onAction('reply'),
        ),
        _tile(
          icon: Icons.forward_rounded,
          label: 'Переслать',
          onTap: () => onAction('forward'),
        ),
        if (text.isNotEmpty)
          _tile(
            icon: AppIcons.copy,
            label: 'Копировать',
            onTap: () => onAction('copy'),
          ),
        if (isMine && messageType == 'text' && text.isNotEmpty)
          _tile(
            icon: AppIcons.edit,
            label: 'Изменить',
            onTap: () => onAction('edit'),
          ),
        if (isMine)
          _tile(
            icon: AppIcons.delete,
            label: 'Удалить',
            danger: true,
            onTap: () => onAction('delete'),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.redAccent : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: danger ? Colors.redAccent : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
