import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
/// Быстрые реакции: первый ряд как в макете, остальные — в развёрнутой сетке.
const List<String> kReactionEmojiPalette = [
  '❤️',
  '🤝',
  '😊',
  '🔥',
  '👍',
  '🤯',
  '😁',
  '😢',
  '👎',
  '🙏',
  '💯',
  '🫡',
];

const List<String> kDefaultQuickReactionEmojis = kReactionEmojiPalette;

const int kCollapsedReactionSlots = 5;

const double _menuRadius = 18;
const double _reactionCellRadius = 12;

bool primaryTapOpensMessageMenu(BuildContext context) {
  if (kIsWeb) {
    return MediaQuery.sizeOf(context).shortestSide < 600;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class ChatMessageActionsPanel extends StatefulWidget {
  const ChatMessageActionsPanel({
    super.key,
    required this.message,
    required this.isMineMessage,
    required this.onAction,
  });

  final Map<String, dynamic> message;
  final bool isMineMessage;
  final ValueChanged<String> onAction;

  @override
  State<ChatMessageActionsPanel> createState() =>
      _ChatMessageActionsPanelState();
}

class _ChatMessageActionsPanelState extends State<ChatMessageActionsPanel> {
  bool _reactionsExpanded = false;

  static const Color _reactionKeyBg = AppColors.chatListCard;

  @override
  Widget build(BuildContext context) {
    final messageType = (widget.message['message_type'] ?? 'text').toString();
    final text = (widget.message['text'] ?? '').toString().trim();
    final mt = messageType.toLowerCase().trim();
    final deliveryStatus = widget.message['delivery_status']?.toString();
    final isFailed = deliveryStatus == 'failed';

    final items = <Widget>[];

    void addTile(
      IconData icon,
      String label,
      String code, {
      bool isDestructive = false,
    }) {
      items.add(
        _actionTile(
          icon: icon,
          label: label,
          onTap: () => widget.onAction(code),
          isDestructive: isDestructive,
        ),
      );
    }

    if (isFailed) {
      addTile(Icons.refresh_rounded, 'Повторить отправку', 'retry');
    } else {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: _reactionSection(),
        ),
      );
      items.add(_menuLine());
      addTile(AppIcons.reply, 'Ответить', 'reply');
    }
    items.add(_menuLine());
    if (!isFailed) {
      addTile(Icons.forward_rounded, 'Переслать', 'forward');
    }
    if (text.isNotEmpty) {
      items.add(_menuLine());
      addTile(AppIcons.copy, 'Копировать', 'copy');
    }
    if (!isFailed && widget.isMineMessage && text.isNotEmpty && mt == 'text') {
      items.add(_menuLine());
      addTile(AppIcons.edit, 'Изменить', 'edit');
    }
    if (!isFailed && widget.isMineMessage) {
      items.add(_menuLine());
      addTile(
        AppIcons.delete,
        'Удалить',
        'delete',
        isDestructive: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171311), Color(0xFF0E0E0E), Color(0xFF17110D)],
        ),
        borderRadius: BorderRadius.circular(_menuRadius),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.24),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...items,
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  /// Реакции (без обёртки-контейнера: она в [build]).
  Widget _reactionSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _reactionsExpanded ? _reactionsWrap() : _reactionsCollapsedRow(),
    );
  }

  Widget _reactionsCollapsedRow() {
    final palette = kReactionEmojiPalette;
    final n = palette.length;
    final showToggle = n > kCollapsedReactionSlots;
    final visible = showToggle ? kCollapsedReactionSlots : n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < visible; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Center(
                child: _reactionCell(
                  onTap: () => widget.onAction('react:${palette[i]}'),
                  child: Center(
                    child: Text(
                      palette[i],
                      style: const TextStyle(fontSize: 21, height: 1.1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showToggle) ...[
          const SizedBox(width: 2),
          _expandCell(),
        ],
      ],
    );
  }

  Widget _reactionsWrap() {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      // Явно по горизонтали — внутри [Wrap] [Material] иначе тянулся на ширину строки.
      direction: Axis.horizontal,
      children: [
        for (final e in kReactionEmojiPalette) ...[
          _reactionCell(
            onTap: () => widget.onAction('react:$e'),
            child: Center(
              child: Text(
                e,
                style: const TextStyle(fontSize: 22, height: 1.1),
              ),
            ),
          ),
        ],
        _expandCell(),
      ],
    );
  }

  static const double _kReactionCellExtent = 44;

  /// Фиксированный квадрат: в [Wrap] иначе [Material] получает maxWidth по строке и
  /// растягивается на всю ширину, из‑за чего смайлики встают в один столбец.
  Widget _reactionCell({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return SizedBox(
      width: _kReactionCellExtent,
      height: _kReactionCellExtent,
      child: Material(
        color: _reactionKeyBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_reactionCellRadius),
          side: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_reactionCellRadius),
          child: child,
        ),
      ),
    );
  }

  Widget _expandCell() {
    // Жёстко 44×44: иначе в [Wrap] [Material] получает maxWidth по строке и
    // [InkWell] теряет нажатия к красной зоне / жесту «свернуть».
    return SizedBox(
      width: _kReactionCellExtent,
      height: _kReactionCellExtent,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip:
            _reactionsExpanded ? 'Свернуть' : 'Ещё реакции',
        style: IconButton.styleFrom(
          backgroundColor: _reactionKeyBg,
          side: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_reactionCellRadius),
          ),
          minimumSize: const Size(44, 44),
          fixedSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () {
          setState(() {
            _reactionsExpanded = !_reactionsExpanded;
          });
        },
        icon: Icon(
          _reactionsExpanded ? Icons.expand_less : Icons.expand_more,
          color: AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }

  static Widget _menuLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.textPrimary.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final destructive = isDestructive;
    final textColor = destructive ? AppColors.error : AppColors.textPrimary;
    final iconColor = destructive ? AppColors.error : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: destructive ? FontWeight.w800 : FontWeight.w600,
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
