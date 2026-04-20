import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../chat_detail_formatters.dart';
import '../chat_detail_message_maps.dart';

/// Цитата «ответ на сообщение» внутри пузырька.
class ChatDetailReplyQuote extends StatelessWidget {
  const ChatDetailReplyQuote({
    super.key,
    required this.message,
    required this.isMine,
    required this.senderNameForUserId,
  });

  final Map<String, dynamic> message;
  final bool isMine;
  final String Function(int? userId) senderNameForUserId;

  @override
  Widget build(BuildContext context) {
    final reply = message['reply_to'];
    if (reply is! Map) {
      return const SizedBox.shrink();
    }

    final map = Map<String, dynamic>.from(reply);
    final senderId = ChatDetailMessageMaps.intFromDynamic(map['sender_id']);
    final senderLabel = senderNameForUserId(senderId);
    final preview = chatDetailReplyPreviewLabel(map);

    final maxQuoteWidth = MediaQuery.sizeOf(context).width * 0.58;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxQuoteWidth),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            decoration: BoxDecoration(
              gradient:
                  isMine ? AppGradients.selectedPanel : AppGradients.surfacePanel,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isMine
                    ? AppColors.accent.withAlpha(80)
                    : AppColors.strokeSoft,
              ),
              boxShadow: AppShadows.lift,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    gradient: AppGradients.accentPanel,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              isMine ? AppColors.accentBright : AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
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
}
