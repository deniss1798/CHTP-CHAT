import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../models/chats_list_filter.dart';

class ChatsListFilterChips extends StatelessWidget {
  const ChatsListFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ChatsListFilter value;
  final ValueChanged<ChatsListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'Все',
            selected: value == ChatsListFilter.all,
            onTap: () => onChanged(ChatsListFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Непрочитанные',
            selected: value == ChatsListFilter.unread,
            onTap: () => onChanged(ChatsListFilter.unread),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Группы',
            selected: value == ChatsListFilter.groups,
            onTap: () => onChanged(ChatsListFilter.groups),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Архив',
            selected: value == ChatsListFilter.archive,
            onTap: () => onChanged(ChatsListFilter.archive),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.navRailActivePill
                : AppColors.chatListCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.navRailActiveAccent
                  : const Color(0xFF2C2C2C),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppColors.navRailActiveAccent
                  : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
