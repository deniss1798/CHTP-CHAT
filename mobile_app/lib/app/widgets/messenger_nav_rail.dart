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
    // Сверху — логотип и три пункта, снизу — профиль; при малой высоте — скролл.
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
              const SizedBox(height: 12),
              _brandHeader(),
              const SizedBox(height: 20),
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
                const SizedBox(height: 12),
                _brandHeader(),
                const SizedBox(height: 20),
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

  Widget _brandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.navRailActiveAccent,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.navRailActiveAccent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'ЧТП',
              style: TextStyle(
                color: Color(0xFF1A0A00),
              fontSize: 9.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'ЧАТ',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
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

        const avatarSize = 40.0;
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                decoration: BoxDecoration(
                  color: AppColors.chatListCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        avatar,
                        Positioned(
                          right: -0.5,
                          bottom: -0.5,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.navRailBackground,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ],
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
