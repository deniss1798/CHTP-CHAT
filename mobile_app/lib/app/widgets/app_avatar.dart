import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/design_tokens.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.title,
    this.imageUrl,
    this.size = AppSizes.listAvatar,
    this.square = false,
    this.radius = AppRadius.md,
  });

  final String title;
  final String? imageUrl;
  final double size;
  final bool square;
  final double radius;

  String get initials {
    final parts =
        title.split(' ').where((part) => part.trim().isNotEmpty).take(2).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first.trim();
      return word.isEmpty ? '?' : word[0].toUpperCase();
    }
    final first = parts.first.trim();
    final second = parts.last.trim();
    return '${first.isEmpty ? '' : first[0]}${second.isEmpty ? '' : second[0]}'
        .toUpperCase();
  }

  BorderRadius get _borderRadius =>
      BorderRadius.circular(square ? radius : AppRadius.pill);

  @override
  Widget build(BuildContext context) {
    final safeUrl = (imageUrl ?? '').trim();
    if (safeUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: _borderRadius,
        child: Image.network(
          safeUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.accentPanel,
        borderRadius: _borderRadius,
        boxShadow: AppShadows.primaryButton,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textOnAccent,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
