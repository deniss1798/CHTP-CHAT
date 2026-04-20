import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';

class ChatDetailFullscreenVideoPage extends StatefulWidget {
  const ChatDetailFullscreenVideoPage({
    super.key,
    required this.url,
    this.isVideoNote = false,
  });

  final String url;
  final bool isVideoNote;

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
    final generation = ++_loadGeneration;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _initError = null;

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _initError = 'РќРµРєРѕСЂСЂРµРєС‚РЅС‹Р№ Р°РґСЂРµСЃ РІРёРґРµРѕ');
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;

    controller.initialize().then((_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _initialized = true;
        _initError = null;
      });
    }).catchError((Object e, _) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _initialized = false;
        _initError = e.toString().replaceFirst('Exception: ', '');
      });
    });

    controller.addListener(() {
      if (!mounted || generation != _loadGeneration) return;
      final playing = controller.value.isPlaying;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildBody()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppIconButtonSurface(
                      icon: AppIcons.close,
                      tooltip: 'Р—Р°РєСЂС‹С‚СЊ',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    AppPillBadge(
                      label:
                          widget.isVideoNote ? 'VIDEO NOTE' : 'VIDEO VIEWER',
                      icon: widget.isVideoNote
                          ? Icons.radio_button_checked_rounded
                          : Icons.ondemand_video_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initError != null) {
      return Center(
        child: AppSurface(
          radius: AppRadius.xxl,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.videocamOff,
                color: AppColors.textMuted,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => setState(_attach),
                icon: const Icon(AppIcons.refresh, color: AppColors.accent),
                label: const Text(
                  'РџРѕРІС‚РѕСЂРёС‚СЊ',
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

    final controller = _controller!;
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
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              );
            },
          )
        : AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppGradients.heroPanel,
                borderRadius: BorderRadius.circular(
                  widget.isVideoNote ? 999 : AppRadius.xxl,
                ),
                border: Border.all(color: AppColors.strokeSoft),
                boxShadow: AppShadows.card,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  widget.isVideoNote ? 999 : AppRadius.xl,
                ),
                child: videoChild,
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _showOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppGradients.heroPanel,
                borderRadius: BorderRadius.circular(29),
                border: Border.all(color: AppColors.strokeSoft),
                boxShadow: AppShadows.lift,
              ),
              alignment: Alignment.center,
              child: Icon(
                controller.value.isPlaying ? AppIcons.pause : AppIcons.play,
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
