import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';

/// Встроенное видео в пузыре (в т.ч. видеокружок).
class ChatDetailVideoMessageWidget extends StatefulWidget {
  final String url;
  final bool isMine;
  final bool isVideoNote;

  /// Для обычного видео: открыть на весь экран. Для кружков ([isVideoNote]) не используется.
  final VoidCallback? onOpenFullscreen;

  const ChatDetailVideoMessageWidget({
    super.key,
    required this.url,
    required this.isMine,
    this.isVideoNote = false,
    this.onOpenFullscreen,
  });

  @override
  State<ChatDetailVideoMessageWidget> createState() =>
      _ChatDetailVideoMessageWidgetState();
}

class _ChatDetailVideoMessageWidgetState
    extends State<ChatDetailVideoMessageWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showOverlay = true;
  String? _initError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  void _attachController() {
    final gen = ++_loadGeneration;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _initError = null;

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _initError = 'Некорректный адрес видео';
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;

    controller.initialize().then((_) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _initialized = true;
        _initError = null;
      });
    }).catchError((Object e, _) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _initialized = false;
        _initError = e.toString().replaceFirst('Exception: ', '');
      });
    });

    if (widget.isVideoNote) {
      controller.addListener(() {
        if (!mounted || gen != _loadGeneration) return;
        final playing = controller.value.isPlaying;
        if (playing) {
          if (_showOverlay) setState(() => _showOverlay = false);
        } else {
          if (!_showOverlay) setState(() => _showOverlay = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _buildSurfaceState(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              AppIcons.videocamOff,
              color: AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              'Не удалось загрузить видео',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'На ПК иногда не поддерживается кодек с телефона. Повторите попытку.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(_attachController),
              icon: const Icon(AppIcons.refresh, size: 18),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return _buildSurfaceState(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textMuted.withAlpha(200),
          ),
        ),
      );
    }

    final controller = _controller!;

    final videoChild = widget.isVideoNote
        ? SizedBox(
            width: 220,
            height: 220,
            child: ClipOval(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          )
        : AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );

    if (widget.isVideoNote) {
      return GestureDetector(
        onTap: _togglePlayback,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(child: videoChild),
            AnimatedOpacity(
              opacity: _showOverlay ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: _buildOverlayButton(
                icon:
                    controller.value.isPlaying ? AppIcons.pause : AppIcons.play,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onOpenFullscreen,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: videoChild),
          _buildOverlayButton(icon: AppIcons.play),
        ],
      ),
    );
  }

  Widget _buildSurfaceState({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(
          widget.isVideoNote ? 999 : 12,
        ),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      alignment: Alignment.center,
      padding: padding,
      child: child,
    );
  }

  Widget _buildOverlayButton({required IconData icon}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
