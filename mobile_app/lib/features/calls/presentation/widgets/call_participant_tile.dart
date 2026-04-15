import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../app/theme/app_colors.dart';

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.surfaceSoft.withValues(alpha: 0.45),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showRenderer)
                  Positioned.fill(
                    child: Opacity(
                      opacity: hasFrame ? 1.0 : 0.02,
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
              ],
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                color: AppColors.surfaceSoft.withValues(alpha: 0.55),
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
                color: AppColors.surfaceSoft.withValues(alpha: 0.35),
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
        color: AppColors.accent.withValues(alpha: 0.35),
      ),
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
