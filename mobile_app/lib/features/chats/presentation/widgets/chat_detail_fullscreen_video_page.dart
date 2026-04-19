import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';

class ChatDetailFullscreenVideoPage extends StatefulWidget {
  final String url;
  final bool isVideoNote;

  const ChatDetailFullscreenVideoPage({
    super.key,
    required this.url,
    this.isVideoNote = false,
  });

  @override
  State<ChatDetailFullscreenVideoPage> createState() =>
      _ChatDetailFullscreenVideoPageState();
}

class _ChatDetailFullscreenVideoPageState
    extends State<ChatDetailFullscreenVideoPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showOverlay = true;
  String? _initError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    final gen = ++_loadGeneration;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _initError = null;

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _initError = 'Некорректный адрес видео');
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(_attach),
                icon: const Icon(AppIcons.refresh, color: AppColors.accent),
                label: const Text(
                  'Повторить',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final c = _controller!;

    final videoChild = widget.isVideoNote
        ? LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide * 0.92;
              return SizedBox(
                width: side,
                height: side,
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
              );
            },
          )
        : AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          );

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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(55),
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: Icon(
                c.value.isPlaying ? AppIcons.pause : AppIcons.play,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
