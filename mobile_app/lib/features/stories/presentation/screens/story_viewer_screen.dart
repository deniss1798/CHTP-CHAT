import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/stories_service.dart';

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

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final StoriesService _service = StoriesService();
  List<Map<String, dynamic>> _stories = [];
  bool _loading = true;
  String? _error;
  String _title = '';
  String? _avatarUrl;

  final PageController _pageController = PageController();
  int _index = 0;
  Timer? _imageTimer;

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
        _scheduleImageAdvance();
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

  void _scheduleImageAdvance() {
    _imageTimer?.cancel();
    if (!mounted || _stories.isEmpty) return;
    final type = (_stories[_index]['media_type'] ?? '').toString();
    if (type == 'video') return;
    _imageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _goNext();
    });
  }

  void _goNext() {
    if (_index < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _goPrev() {
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
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

  @override
  void dispose() {
    _imageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentBright)),
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
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: _onTap,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) {
                setState(() => _index = i);
                unawaited(_markViewedForIndex(i));
                _scheduleImageAdvance();
              },
              itemCount: _stories.length,
              itemBuilder: (context, i) {
                final s = _stories[i];
                final url = (s['media_url'] ?? '').toString();
                final type = (s['media_type'] ?? '').toString();
                final cap = (s['caption'] ?? '').toString().trim();
                if (type == 'video') {
                  return _StoryVideoPage(url: url, caption: cap);
                }
                return _StoryImagePage(url: url, caption: cap);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Text(
                            _title.isNotEmpty ? _title[0].toUpperCase() : '?',
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
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 52,
            left: 12,
            right: 12,
            child: Row(
              children: List.generate(_stories.length, (i) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i == _stories.length - 1 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: i < _index
                          ? Colors.white
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }),
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
        Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, p) {
            if (p == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentBright),
            );
          },
        ),
        if (caption.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
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
  const _StoryVideoPage({required this.url, required this.caption});

  final String url;
  final String caption;

  @override
  State<_StoryVideoPage> createState() => _StoryVideoPageState();
}

class _StoryVideoPageState extends State<_StoryVideoPage> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    final ctrl = VideoPlayerController.networkUrl(uri);
    _c = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _c;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ctrl != null && ctrl.value.isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: VideoPlayer(ctrl),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          ),
        if (widget.caption.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
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
