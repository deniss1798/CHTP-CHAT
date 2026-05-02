import 'package:flutter/material.dart';

import '../../core/network/url_helper.dart';
import '../../core/session/current_user_store.dart';
import '../../features/chats/domain/chat_list_rules.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import 'authorized_network_image.dart';

/// Левая навигация 1-в-1 с макетом: чёрный фон, активный пункт с оранжевой
/// вертикальной полосой и тёмно-коричневой подложкой, неактивные — #8E8E8E.
class MessengerNavRail extends StatelessWidget {
  const MessengerNavRail({
    super.key,
    required this.railHeight,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  /// Высота с [MessengerDesktopShell] (жёстко задана у [SizedBox]).
  final double railHeight;

  static const int chatsIndex = 0;
  static const int contactsIndex = 1;
  static const int settingsIndex = 2;

  static const double _width = 80;

  /// Ширина рейла — для оболочки ([MessengerDesktopShell]).
  static const double railWidth = _width;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final h = railHeight;
    if (h <= 0) {
      return const SizedBox(width: _width, height: 0);
    }

    // Без Column+Spacer: на web/отдельных кадрах Spacer схлопывался.
    // Сверху — пункты навигации, снизу — профиль; при малой высоте — скролл.
    if (h < 240) {
      return Container(
        width: _width,
        height: h,
        decoration: const BoxDecoration(
          color: AppColors.navRailBackground,
          border: Border(
            right: BorderSide(color: AppColors.strokeSoft, width: 1),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _navItems(),
              const SizedBox(height: 12),
              const _NavProfileFooter(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    return Container(
      width: _width,
      height: h,
      decoration: const BoxDecoration(
        color: AppColors.navRailBackground,
        border: Border(
          right: BorderSide(color: AppColors.strokeSoft, width: 1),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _navItems(),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: _NavProfileFooter(),
          ),
        ],
      ),
    );
  }

  /// Три пункта навигации (Чаты / Контакты / Настройки).
  Widget _navItems() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavItem(
          label: 'Чаты',
          isActive: selectedIndex == chatsIndex,
          onTap: () => onDestinationSelected(chatsIndex),
          icon: Icons.chat_bubble_outline_rounded,
        ),
        const SizedBox(height: 6),
        _NavItem(
          label: 'Контакты',
          isActive: selectedIndex == contactsIndex,
          onTap: () => onDestinationSelected(contactsIndex),
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 6),
        _NavItem(
          label: 'Настройки',
          isActive: selectedIndex == settingsIndex,
          onTap: () => onDestinationSelected(settingsIndex),
          icon: Icons.settings_outlined,
        ),
      ],
    );
  }

}

class _NavProfileFooter extends StatelessWidget {
  const _NavProfileFooter();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CurrentUserStore.userVersion,
      builder: (context, value, child) {
        final u = CurrentUserStore.user;
        var display = 'Профиль';
        if (u != null) {
          final n = (u['name'] ?? u['username'] ?? u['email'] ?? '').toString().trim();
          if (n.isNotEmpty) display = n;
        }

        const avatarSize = 44.0;
        final raw = u?['avatar_url'] ?? u?['avatarUrl'];
        final imageUrl = UrlHelper.absoluteMediaUrl(raw);
        final safe = (imageUrl ?? '').trim();

        void open() {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const ProfileScreen(),
            ),
          );
        }

        Widget roundAvatar(Widget child) {
          return ClipOval(
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: child,
            ),
          );
        }

        final avatar = safe.isNotEmpty
            ? roundAvatar(
                ColoredBox(
                  color: AppColors.chatListCard,
                  child: AuthorizedNetworkImage(
                    url: safe,
                    width: avatarSize,
                    height: avatarSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _ProfileGlyphFallback(name: display, size: avatarSize),
                  ),
                ),
              )
            : roundAvatar(
                _ProfileGlyphFallback(name: display, size: avatarSize),
              );

        return Padding(
          key: ValueKey<int>(value),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.chatListCard.withValues(alpha: 0.94),
                      AppColors.chatListCard.withValues(alpha: 0.76),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.strokeSoft.withValues(alpha: 0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.navRailActiveAccent.withValues(alpha: 0.35),
                              width: 1.8,
                            ),
                          ),
                          child: avatar,
                        ),
                        Positioned(
                          right: -0.5,
                          bottom: -0.5,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.navRailBackground,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      display,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileGlyphFallback extends StatelessWidget {
  const _ProfileGlyphFallback({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navRailActivePill,
      child: Center(
        child: Text(
          resolveTitleInitials(name),
          style: const TextStyle(
            color: AppColors.navRailActiveAccent,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const double barW = 3.0;
    const double radius = 12;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius + 1),
          splashColor: AppColors.navRailActiveAccent.withAlpha(30),
          highlightColor: AppColors.navRailActiveAccent.withAlpha(12),
          child: isActive
              ? Container(
                  decoration: BoxDecoration(
                    color: AppColors.navRailActivePill,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: AppColors.navRailActiveAccent.withValues(alpha: 0.7),
                    ),
                    boxShadow: AppShadows.accentStroke,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: barW,
                        decoration: BoxDecoration(
                          color: AppColors.navRailActiveAccent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 4, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                size: 24,
                                color: AppColors.navRailActiveAccent,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: AppColors.navRailActiveAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: AppColors.navRailInactive,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: AppColors.navRailInactive,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
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
