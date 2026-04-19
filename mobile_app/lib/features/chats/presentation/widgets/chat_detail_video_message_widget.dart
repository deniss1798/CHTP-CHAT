import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';

/// Встроенное видео в пузыре сообщения (в т.ч. video note).
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

    final c = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = c;

    c.initialize().then((_) {
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
      c.addListener(() {
        if (!mounted || gen != _loadGeneration) return;
        final playing = c.value.isPlaying;
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
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    const loadingBg = Color(0x00000000);

    if (_initError != null) {
      return Container(
        color: loadingBg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.videocamOff,
              color: AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Не удалось загрузить видео',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'На ПК иногда не поддерживается кодек с телефона. Повторите попытку.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
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
      return Container(
        color: loadingBg,
        alignment: Alignment.center,
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent.withAlpha(220),
          ),
        ),
      );
    }

    final c = _controller!;

    final videoChild = widget.isVideoNote
        ? SizedBox(
            width: 220,
            height: 220,
            child: ClipOval(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          )
        : AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
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
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(55),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Icon(
                  c.value.isPlaying ? AppIcons.pause : AppIcons.play,
                  color: Colors.white,
                  size: 24,
                ),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(55),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              AppIcons.play,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
