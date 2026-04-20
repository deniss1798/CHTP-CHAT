import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../core/network/url_helper.dart';
import '../../data/services/profile_service.dart';

/// Профиль другого пользователя (по нажатию на аватар в личном чате).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ProfileService _profileService = ProfileService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await _profileService.getUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = u;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'Не удалось загрузить профиль';
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map) {
          msg = d['detail']?.toString() ?? msg;
        }
      }
      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  String? _avatarUrl() {
    final raw = (_user?['avatar_url'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    return UrlHelper.absoluteMediaUrl(raw);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= AppBreakpoints.wideLayoutMinWidth;
    final avatarSize = isWide ? 168.0 : 120.0;
    final cardMaxWidth = isWide ? 440.0 : double.infinity;
    final username = (_user?['username'] ?? 'Пользователь').toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 8,
              child: AppIconButtonSurface(
                icon: AppIcons.back,
                tooltip: 'Назад',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? AppSpacing.xxxl : AppSpacing.xxl,
                    vertical: AppSpacing.xxxl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    child: _loading
                        ? _loadingBlock(isWide)
                        : _error != null
                            ? _errorBlock(isWide)
                            : _profileCard(
                                username: username,
                                avatarSize: avatarSize,
                                isWide: isWide,
                              ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingBlock(bool isWide) {
    return SizedBox(
      height: isWide ? 320 : 240,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }

  Widget _errorBlock(bool isWide) {
    return AppSurface(
      tone: AppSurfaceTone.elevated,
      radius: AppRadius.xxl,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _load,
              child: const Text('Повторить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard({
    required String username,
    required double avatarSize,
    required bool isWide,
  }) {
    return AppSurface(
      tone: AppSurfaceTone.elevated,
      radius: AppRadius.xxl,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? AppSpacing.xxxl : AppSpacing.xxl,
        vertical: isWide ? 40 : AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppPillBadge(label: 'PUBLIC PROFILE', accent: true),
          SizedBox(height: isWide ? 28 : AppSpacing.xl),
          _buildAvatar(username, avatarSize),
          SizedBox(height: isWide ? 28 : AppSpacing.xl),
          Text(
            username,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isWide ? 22 : 20,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Участник ЧТП ЧАТ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: isWide ? 15 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String title, double size) {
    final url = _avatarUrl();
    final radius = size * 0.22;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackAvatar(title, size, radius),
        ),
      );
    }
    return _fallbackAvatar(title, size, radius);
  }

  Widget _fallbackAvatar(String title, double size, double radius) {
    final ch = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.accentPanel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.primaryButton,
      ),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: TextStyle(
          color: AppColors.textOnAccent,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
