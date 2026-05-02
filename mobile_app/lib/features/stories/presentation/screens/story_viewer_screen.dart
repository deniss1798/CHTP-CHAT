import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/stories_service.dart';

const Duration _kImageStoryDuration = Duration(seconds: 5);

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.authorId,
    this.initialUsername,
    this.initialAvatarUrl,
  });

  final int authorId;
  final String? initialUsername;
  final String? initialAvatarUrl;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  final StoriesService _service = StoriesService();
  List<Map<String, dynamic>> _stories = [];
  bool _loading = true;
  String? _error;
  String _title = '';
  String? _avatarUrl;

  final PageController _pageController = PageController();
  int _index = 0;

  AnimationController? _imageProgress;
  double _videoProgressNorm = 0;

  @override
  void initState() {
    super.initState();
    _title = widget.initialUsername ?? '';
    _avatarUrl = widget.initialAvatarUrl;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await _service.getUserStories(authorId: widget.authorId);
      final user = data['user'];
      if (user is Map) {
        final um = Map<String, dynamic>.from(user);
        _title = (um['username'] ?? _title).toString();
        _avatarUrl = um['avatar_url']?.toString() ?? _avatarUrl;
      }
      final raw = data['stories'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final s in raw) {
          if (s is Map) {
            list.add(Map<String, dynamic>.from(s));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _stories = list;
        _loading = false;
        _error = list.isEmpty ? 'Нет активных сторис' : null;
      });
      if (list.isNotEmpty) {
        unawaited(_markViewedForIndex(0));
        _beginSegmentProgress(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _markViewedForIndex(int i) async {
    if (i < 0 || i >= _stories.length) return;
    final id = _stories[i]['id'];
    final sid = id is int ? id : int.tryParse(id.toString());
    if (sid == null) return;
    try {
      await _service.markViewed(sid);
    } catch (_) {}
  }

  void _disposeImageProgress() {
    _imageProgress?.dispose();
    _imageProgress = null;
  }

  void _beginSegmentProgress(int pageIndex) {
    _disposeImageProgress();
    if (!mounted || pageIndex < 0 || pageIndex >= _stories.length) return;

    final type = (_stories[pageIndex]['media_type'] ?? '').toString();
    setState(() => _videoProgressNorm = 0);

    if (type.toLowerCase() == 'video') {
      return;
    }

    final ctrl = AnimationController(
      vsync: this,
      duration: _kImageStoryDuration,
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          _goNext();
        }
      });

    _imageProgress = ctrl;
    ctrl.forward(from: 0);
  }

  double _segmentFill(int segmentIndex) {
    final n = _stories.length;
    if (segmentIndex < 0 || segmentIndex >= n) return 0;

    if (segmentIndex < _index) return 1;
    if (segmentIndex > _index) return 0;

    final type = (_stories[_index]['media_type'] ?? '').toString();
    if (type.toLowerCase() == 'video') {
      return _videoProgressNorm.clamp(0.0, 1.0);
    }
    return (_imageProgress?.value ?? 0).clamp(0.0, 1.0);
  }

  void _goNext() {
    if (_index < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _goPrev() {
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onTap(TapUpDetails d) {
    final w = MediaQuery.sizeOf(context).width;
    if (d.globalPosition.dx < w / 3) {
      _goPrev();
    } else {
      _goNext();
    }
  }

  void _onVideoTick(double normalized) {
    if (!mounted) return;
    setState(() => _videoProgressNorm = normalized);
  }

  void _onVideoEnded() {
    if (!mounted) return;
    _goNext();
  }

  @override
  void dispose() {
    _disposeImageProgress();
    _pageController.dispose();
    super.dispose();
  }

  Widget _segmentProgressBar() {
    final n = _stories.length;
    if (n <= 0) return const SizedBox.shrink();

    return Row(
      children: List.generate(n, (i) {
        final fill = _segmentFill(i);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == n - 1 ? 0 : 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 3.6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.26),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fill.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.96),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentBright),
        ),
      );
    }

    if (_error != null || _stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Пусто',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                ? NetworkImage(_avatarUrl!)
                                : null,
                        child:
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                                ? Text(
                                    _title.isNotEmpty
                                        ? _title[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: _segmentProgressBar(),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: _onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accentBright
                                .withValues(alpha: 0.34),
                            width: 1.35,
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 36,
                              spreadRadius: -2,
                              color:
                                  AppColors.accentGlow.withValues(alpha: 0.28),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(17.5),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _stories.length,
                                onPageChanged: (i) {
                                  setState(() => _index = i);
                                  unawaited(_markViewedForIndex(i));
                                  _beginSegmentProgress(i);
                                },
                                itemBuilder: (context, i) {
                                  final s = _stories[i];
                                  final url =
                                      (s['media_url'] ?? '').toString();
                                  final type = (s['media_type'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final cap =
                                      (s['caption'] ?? '').toString().trim();
                                  final active = i == _index;

                                  if (type == 'video') {
                                    return _StoryVideoPage(
                                      url: url,
                                      caption: cap,
                                      active: active,
                                      onTick:
                                          active ? _onVideoTick : null,
                                      onEnded: active ? _onVideoEnded : null,
                                    );
                                  }
                                  return _StoryImagePage(
                                    url: url,
                                    caption: cap,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryImagePage extends StatelessWidget {
  const _StoryImagePage({required this.url, required this.caption});

  final String url;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black),
        Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          loadingBuilder: (context, child, p) {
            if (p == null) return child!;
            return const Center(
              child:
                  CircularProgressIndicator(color: AppColors.accentBright),
            );
          },
        ),
        if (caption.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Text(
              caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
      ],
    );
  }
}

class _StoryVideoPage extends StatefulWidget {
  const _StoryVideoPage({
    required this.url,
    required this.caption,
    required this.active,
    this.onTick,
    this.onEnded,
  });

  final String url;
  final String caption;
  final bool active;
  final void Function(double normalized)? onTick;
  final VoidCallback? onEnded;

  @override
  State<_StoryVideoPage> createState() => _StoryVideoPageState();
}

class _StoryVideoPageState extends State<_StoryVideoPage> {
  VideoPlayerController? _c;

  bool _endedNotified = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;

    final ctrl = VideoPlayerController.networkUrl(uri);
    _c = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(false);
      ctrl.addListener(_onVideoPulse);

      _endedNotified = false;
      if (widget.active && mounted) {
        await ctrl.play();
      }

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _onVideoPulse() {
    if (!widget.active) return;

    final ctrl = _c;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    final dur = ctrl.value.duration;
    final totalMs = dur.inMilliseconds;
    if (totalMs <= 0) return;

    final posMs = ctrl.value.position.inMilliseconds;
    final norm = posMs / totalMs;
    widget.onTick?.call(norm.clamp(0.0, 1.0));

    if (!_endedNotified &&
        dur > Duration.zero &&
        ctrl.value.position >= dur - const Duration(milliseconds: 160)) {
      _endedNotified = true;
      widget.onEnded?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _StoryVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final ctrl = _c;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (widget.active && !oldWidget.active) {
      _endedNotified = false;
      unawaited(ctrl.seekTo(Duration.zero));
      ctrl.play();
    } else if (!widget.active && oldWidget.active) {
      ctrl.pause();
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_onVideoPulse);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _c;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black),
        if (ctrl != null && ctrl.value.isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio > 0
                  ? ctrl.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(ctrl),
            ),
          )
        else
          const Center(
            child:
                CircularProgressIndicator(color: AppColors.accentBright),
          ),
        if (widget.caption.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Text(
              widget.caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
      ],
    );
  }
}
