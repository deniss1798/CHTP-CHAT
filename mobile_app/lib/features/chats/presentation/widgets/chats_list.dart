import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../models/chat_list_item_model.dart';
import 'chat_list_item.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({
    super.key,
    required this.items,
    required this.embedded,
    required this.onRefresh,
    required this.onTap,
    this.onLongPress,
    this.bottomPadding,
  });

  final List<ChatListItemModel> items;
  final bool embedded;
  final Future<void> Function() onRefresh;
  final ValueChanged<ChatListItemModel> onTap;
  final void Function(ChatListItemModel item)? onLongPress;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          embedded ? 12 : 20,
          0,
          embedded ? 12 : 20,
          bottomPadding ?? (embedded ? 96 : 110),
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 5),
        itemBuilder: (context, index) {
          final item = items[index];
          return ChatListItem(
            item: item,
            onTap: () => onTap(item),
            onLongPress:
                onLongPress != null ? () => onLongPress!(item) : null,
          );
        },
      ),
    );
  }
}
