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
                if (!hasFrame && attachHiddenVideoSurface)
                  Opacity(
                    opacity: 0,
                    child: RTCVideoView(
                      renderer,
                      mirror: mirror,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                if (hasFrame)
                  RTCVideoView(
                    renderer,
                    mirror: mirror,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                else
                  _buildAvatarPlace(context),
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
    return Center(
      child: CircleAvatar(
        radius: 44,
        backgroundColor: AppColors.accent.withValues(alpha: 0.35),
        backgroundImage: (u != null && u.isNotEmpty) ? NetworkImage(u) : null,
        child: (u == null || u.isEmpty)
            ? Text(
                _initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}
