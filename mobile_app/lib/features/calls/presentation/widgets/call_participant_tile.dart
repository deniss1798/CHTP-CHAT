import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';

/// Плитка участника: видео или аватар (если камера выкл / нет кадра).
class CallParticipantTile extends StatelessWidget {
  const CallParticipantTile({
    super.key,
    required this.label,
    required this.renderer,
    this.avatarUrl,
    this.showVideo = false,
    this.mirror = false,
    this.attachHiddenVideoSurface = false,
  });

  final String label;
  final RTCVideoRenderer renderer;
  final String? avatarUrl;
  final bool showVideo;
  final bool mirror;

  /// На части платформ без скрытого [RTCVideoView] не воспроизводится удалённое аудио.
  final bool attachHiddenVideoSurface;

  static bool rendererHasLiveVideo(RTCVideoRenderer r) {
    final o = r.srcObject;
    if (o == null) return false;
    for (final t in o.getVideoTracks()) {
      if (t.enabled) return true;
    }
    return false;
  }

  String get _initial {
    final t = label.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasFrame = showVideo && rendererHasLiveVideo(renderer);

    /// Один [RTCVideoView] на [renderer], иначе при переключении «аудио+аватар» ↔ «видео»
    /// Flutter снимает один виджет и создаёт другой — аудио обрывается (особенно desktop).
    final showRenderer =
        attachHiddenVideoSurface || hasFrame || showVideo;

    /// Один и тот же [RTCVideoView] на весь тайл: нельзя менять layout (2×2 → fullscreen) при
    /// появлении кадра — иначе Flutter пересоздаёт виджет и WebRTC зависает/рвёт звук.
    /// Без кадра: чуть выше прозрачность, если нужен скрытый вывод аудио (attachHiddenVideoSurface).
    final hiddenOpacity =
        attachHiddenVideoSurface && !hasFrame ? 0.08 : 0.02;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.heroPanel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.strokeSoft),
              boxShadow: AppShadows.card,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showRenderer)
                  Positioned.fill(
                    child: Opacity(
                      opacity: hasFrame ? 1.0 : hiddenOpacity,
                      child: RTCVideoView(
                        renderer,
                        mirror: mirror,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                if (!hasFrame)
                  Positioned.fill(
                    child: IgnorePointer(
                          child: Center(child: _buildAvatarPlace(context)),
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(110),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.strokeSoft),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlace(BuildContext context) {
    final u = avatarUrl?.trim();
    const size = 88.0;
    if (u == null || u.isEmpty) {
      return Center(child: _avatarInitialFallback(size));
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round();
    return Center(
      child: RepaintBoundary(
        child: ClipOval(
          child: Image.network(
            u,
            key: ValueKey<String>(u),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            cacheWidth: cachePx,
            cacheHeight: cachePx,
            headers: const {
              'User-Agent': 'CHTP-Chat/1.0 (Flutter; avatar)',
              'Accept': 'image/*,*/*;q=0.8',
            },
            errorBuilder: (context, error, stackTrace) =>
                _avatarInitialFallback(size),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: AppGradients.surfacePanel,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                    value: progress.expectedTotalBytes != null &&
                            progress.expectedTotalBytes! > 0
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) {
                return child;
              }
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: AppGradients.surfacePanel,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent.withValues(alpha: 0.85),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _avatarInitialFallback(double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.accentPanel,
        boxShadow: AppShadows.primaryButton,
      ),
      child: Text(
        _initial,
        style: TextStyle(
          color: AppColors.textOnAccent,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
