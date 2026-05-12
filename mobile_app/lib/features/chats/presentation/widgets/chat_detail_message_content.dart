import 'dart:async' show unawaited;
import 'dart:math' show Random;
import 'dart:ui' show FontFeature;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/chat_attachment_opener.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../chat_detail_formatters.dart';
import 'chat_detail_video_message_widget.dart';

class ChatDetailMessageContent extends StatelessWidget {
  const ChatDetailMessageContent({
    super.key,
    required this.message,
    required this.isMine,
    required this.onOpenFullscreenImage,
    required this.onOpenFullscreenVideo,
  });

  final Map<String, dynamic> message;
  final bool isMine;
  final void Function(String url) onOpenFullscreenImage;
  final void Function(String url, {required bool isVideoNote})
      onOpenFullscreenVideo;

  @override
  Widget build(BuildContext context) {
    final messageType = (message['message_type'] ?? 'text').toString();
    final mediaUrl = (message['media_url'] ?? '').toString().trim();

    if (messageType == 'deleted' || message['is_deleted'] == true) {
      return const Text(
        'Сообщение удалено',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          height: 1.35,
        ),
      );
    }

    if (messageType == 'poll') {
      return _buildPollCard(context);
    }

    if (messageType == 'call_event') {
      return Text(
        (message['text'] ?? 'Вызов').toString(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      );
    }

    if (messageType == 'voice' && mediaUrl.isNotEmpty) {
      return _VoiceMessageBar(url: mediaUrl, isMine: isMine);
    }

    if ((messageType == 'document' || messageType == 'file') && mediaUrl.isNotEmpty) {
      return Builder(builder: (ctx) => _buildDocumentCard(ctx, mediaUrl));
    }

    if (messageType == 'video_note' && mediaUrl.isNotEmpty) {
      return SizedBox(
        width: 220,
        height: 220,
        child: ChatDetailVideoMessageWidget(
          url: mediaUrl,
          isMine: isMine,
          isVideoNote: true,
        ),
      );
    }

    if (messageType == 'image' && mediaUrl.isNotEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpenFullscreenImage(mediaUrl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 260,
            maxHeight: 360,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return ColoredBox(
                    color: AppColors.surfaceSoft,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textMuted.withAlpha(200),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: AppColors.surfaceSoft,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Не удалось загрузить фото',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    if (messageType == 'video' && mediaUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 260,
          maxHeight: 320,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ChatDetailVideoMessageWidget(
            url: mediaUrl,
            isMine: isMine,
            isVideoNote: false,
            onOpenFullscreen: () =>
                onOpenFullscreenVideo(mediaUrl, isVideoNote: false),
          ),
        ),
      );
    }

    final plain = (message['text'] ?? '').toString();
    final baseStyle = TextStyle(
      color: isMine ? Colors.white : AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    return SelectionArea(
      child: SelectableLinkify(
        onOpen: (link) async {
          final uri = Uri.tryParse(link.url);
          if (uri == null) return;
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        text: plain,
        style: baseStyle,
        linkStyle: baseStyle.copyWith(
          color: isMine
              ? const Color(0xFFB8E0FF)
              : AppColors.accentBright,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: (isMine
                  ? const Color(0xFFB8E0FF)
                  : AppColors.accentBright)
              .withAlpha(200),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, String mediaUrl) {
    final name = (message['text'] ?? '').toString().trim();
    final sizeLabel = chatDetailFormatDocSize(message['media_size']);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 292),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openChatAttachmentUrl(
            context,
            mediaUrl: mediaUrl,
            fallbackFileName: name,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isMine
                  ? AppColors.surfaceHighlight
                  : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.strokeSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isEmpty ? 'Файл' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sizeLabel != null)
                        Text(
                          sizeLabel,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPollCard(BuildContext context) {
    return _PollMessageWidget(message: message);
  }
}

class _PollMessageWidget extends StatelessWidget {
  const _PollMessageWidget({required this.message});

  final Map<String, dynamic> message;

  Map<String, dynamic>? get _poll {
    final p = message['poll'];
    if (p is Map) return Map<String, dynamic>.from(p);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    final question = (message['text'] ?? '').toString().trim();
    if (poll == null) {
      return Text(
        question.isEmpty ? 'Опрос' : question,
        style: const TextStyle(color: AppColors.textPrimary),
      );
    }

    final messageId = message['id'];
    final isAnonymous = poll['is_anonymous'] == true;
    final isClosed = poll['is_closed'] == true;
    final allowsMultiple = poll['allows_multiple'] == true;
    final totalVotes = (poll['total_votes'] as int?) ?? 0;
    final options = (poll['options'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (question.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              question,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        Text(
          isAnonymous ? 'Анонимный опрос' : 'Открытый опрос',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final opt in options)
          _PollOptionTile(
            messageId: messageId is int
                ? messageId
                : int.tryParse('$messageId') ?? 0,
            option: opt,
            totalVotes: totalVotes,
            allowsMultiple: allowsMultiple,
            isClosed: isClosed,
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              _votesLabel(totalVotes),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isClosed) ...[
              const SizedBox(width: 8),
              const Text(
                '• Завершён',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _votesLabel(int total) {
    if (total == 0) return 'Голосов пока нет';
    final mod10 = total % 10;
    final mod100 = total % 100;
    if (mod10 == 1 && mod100 != 11) return '$total голос';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$total голоса';
    }
    return '$total голосов';
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.messageId,
    required this.option,
    required this.totalVotes,
    required this.allowsMultiple,
    required this.isClosed,
  });

  final int messageId;
  final Map<String, dynamic> option;
  final int totalVotes;
  final bool allowsMultiple;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    final text = (option['text'] ?? '').toString();
    final votes = (option['votes'] as int?) ?? 0;
    final votedByMe = option['voted_by_me'] == true;
    final share = totalVotes > 0 ? votes / totalVotes : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isClosed
            ? null
            : () {
                final cb = _PollTapBus.instance.handler;
                cb?.call(messageId, (option['id'] as int?) ?? 0, allowsMultiple);
              },
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(color: AppColors.surfaceSoft),
                        Container(
                          width: constraints.maxWidth * share,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.22),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    votedByMe
                        ? (allowsMultiple
                            ? Icons.check_box_rounded
                            : Icons.radio_button_checked)
                        : (allowsMultiple
                            ? Icons.check_box_outline_blank_rounded
                            : Icons.radio_button_unchecked),
                    color: votedByMe
                        ? AppColors.accent
                        : AppColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    totalVotes == 0
                        ? '0%'
                        : '${((share * 100).round())}%',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef PollVoteHandler = void Function(
  int messageId,
  int optionId,
  bool allowsMultiple,
);

/// Лёгкая шина, чтобы передать обработчик тапа по варианту опроса
/// из ChatDetailScreen в глубоко вложенный _PollOptionTile без
/// расширения существующего API ChatDetailMessageContent.
class _PollTapBus {
  _PollTapBus._();
  static final _PollTapBus instance = _PollTapBus._();
  PollVoteHandler? handler;
}

class PollVoteBus {
  PollVoteBus._();
  static void setHandler(PollVoteHandler? handler) {
    _PollTapBus.instance.handler = handler;
  }
}

class _VoiceMessageBar extends StatefulWidget {
  const _VoiceMessageBar({
    required this.url,
    required this.isMine,
  });

  final String url;
  final bool isMine;

  @override
  State<_VoiceMessageBar> createState() => _VoiceMessageBarState();
}

class _VoiceMessageBarState extends State<_VoiceMessageBar> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late List<double> _waveHeights;
  int _playbackIndex = 0;

  late final List<double> _rates =
      widget.isMine ? const [1.0, 1.5, 2.0] : const [1.0, 1.5];

  @override
  void initState() {
    super.initState();
    final rnd = Random(widget.url.hashCode);
    _waveHeights = List<double>.generate(36, (index) {
      var r = rnd.nextDouble().clamp(0.15, 1.0);
      if ((index.isEven && index % 4 == 0) || (index % 9 == 0)) {
        r = (r + 0.25).clamp(0.35, 1.0);
      }
      return r;
    });

    _player.onPlayerStateChanged.listen((PlayerState s) {
      if (mounted) setState(() => _playerState = s);
    });
    _player.onDurationChanged.listen((Duration d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((Duration p) {
      if (mounted) setState(() => _position = p);
    });
  }

  double get _playbackRate => _rates[_playbackIndex.clamp(0, _rates.length - 1)];

  double get _progress {
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    final p = _position.inMilliseconds / total;
    return p.clamp(0.0, 1.0);
  }

  String _formatSpeedChip(double rate) {
    if (rate == 1.0) return '1×';
    if (rate == 1.5) return '1.5×';
    if (rate == 2.0) return '2×';
    return '${rate.toStringAsFixed(1)}×';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_playerState == PlayerState.paused || _playerState == PlayerState.completed) {
      if (_playerState == PlayerState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.setPlaybackRate(_playbackRate);
      await _player.resume();
      return;
    }
    await _player.setPlaybackRate(_playbackRate);
    await _player.play(UrlSource(widget.url));
  }

  Future<void> _toggleSpeed() async {
    HapticFeedback.lightImpact();
    setState(() {
      _playbackIndex = (_playbackIndex + 1) % _rates.length;
    });
    if (_playerState == PlayerState.playing) {
      await _player.setPlaybackRate(_playbackRate);
    }
  }

  Future<void> _seekToFraction(double f) async {
    if (_duration.inMilliseconds <= 0) return;
    final frac = f.clamp(0.0, 1.0);
    await _player.seek(
      Duration(milliseconds: (frac * _duration.inMilliseconds).round()),
    );
  }

  String _fmtDur(Duration d) {
    final s = d.inSeconds.clamp(0, 5999);
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Color _primaryOnBubble() =>
      widget.isMine ? Colors.white : AppColors.textPrimary;

  Color _mutedOnBubble() => widget.isMine
      ? Colors.white.withValues(alpha: 0.72)
      : AppColors.textSecondary;

  Color _accentLine() =>
      widget.isMine ? Colors.white.withValues(alpha: 0.92) : AppColors.accentBright;

  Color _inactiveLine() =>
      widget.isMine ? Colors.white.withValues(alpha: 0.26) : AppColors.strokeSoft;

  Color _playbackChipBg() => widget.isMine
      ? Colors.black.withValues(alpha: 0.18)
      : AppColors.accent.withValues(alpha: 0.15);

  @override
  Widget build(BuildContext context) {
    final playing = _playerState == PlayerState.playing;
    final hasDuration = _duration.inMilliseconds > 50;
    final remaining = Duration(
      milliseconds: (_duration.inMilliseconds - _position.inMilliseconds)
          .clamp(0, 999999999),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 268, maxWidth: 296),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isMine
                        ? LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.38),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: widget.isMine ? null : AppColors.chatListCard.withValues(alpha: 0.92),
                    border: Border.all(
                      color: widget.isMine
                          ? Colors.white.withValues(alpha: 0.45)
                          : AppColors.strokeSoft.withValues(alpha: 0.85),
                      width: 1.05,
                    ),
                    boxShadow: widget.isMine
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: _primaryOnBubble(),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, cons) {
                    final waveW = cons.maxWidth;
                    Future<void> seekFromDx(double dx) {
                      final frac = (dx / waveW).clamp(0.0, 1.0);
                      return _seekToFraction(frac);
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) {
                        unawaited(seekFromDx(d.localPosition.dx));
                        HapticFeedback.selectionClick();
                      },
                      onHorizontalDragUpdate: (d) =>
                          unawaited(seekFromDx(d.localPosition.dx)),
                      child: SizedBox(
                        width: cons.maxWidth,
                        height: 36,
                        child: CustomPaint(
                          painter: _VoiceWavePainter(
                            heights01: _waveHeights,
                            progress: hasDuration ? _progress : 0,
                            playedColor: _accentLine(),
                            unplayedColor: _inactiveLine(),
                            isMine: widget.isMine,
                          ),
                          size: Size(cons.maxWidth, 36),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          hasDuration ? _fmtDur(_position) : '',
                          style: TextStyle(
                            color: _mutedOnBubble(),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleSpeed,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _playbackChipBg(),
                          ),
                          child: Text(
                            _formatSpeedChip(_playbackRate),
                            style: TextStyle(
                              color: _primaryOnBubble().withValues(
                                alpha: _playbackRate == 1 ? 0.55 : 0.95,
                              ),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          hasDuration ? '-${_fmtDur(remaining)}' : '',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _mutedOnBubble(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
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

class _VoiceWavePainter extends CustomPainter {
  _VoiceWavePainter({
    required this.heights01,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.isMine,
  });

  final List<double> heights01;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final bool isMine;

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights01.length;
    if (n == 0 || size.width <= 6) return;
    final gap = size.width / n;
    final barW = gap * 0.46;
    final baseY = size.height * 0.85;

    final playedEnd = progress * size.width;

    final paintPlayed = Paint()
      ..color = playedColor.withValues(alpha: isMine ? 0.92 : 0.95)
      ..strokeCap = StrokeCap.round;

    final paintUnplayed = Paint()
      ..color = unplayedColor.withValues(alpha: isMine ? 0.42 : 0.55)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < n; i++) {
      final x = gap * i + gap * 0.5;
      final h = (size.height - 8) * (0.2 + heights01[i] * 0.8);
      final top = baseY - h;
      final drawn = x < playedEnd ? paintPlayed : paintUnplayed;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barW / 2, top, barW, h),
          Radius.circular(barW / 2),
        ),
        drawn,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.heights01 != heights01;
}
