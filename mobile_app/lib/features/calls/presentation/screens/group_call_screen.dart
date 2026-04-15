import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../core/network/api_client.dart';
import '../../../chats/data/services/chat_socket_service.dart';
import '../../data/group_call_session.dart';

/// Групповой аудио/видеозвонок (mesh WebRTC) в групповом чате.
class GroupCallScreen extends StatefulWidget {
  const GroupCallScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.myUserId,
    required this.callId,
    required this.startedByUserId,
    required this.memberNames,
    this.existingSocket,
    this.isHost = false,
    this.startWithVideo = true,
    this.incomingInvite,
  });

  final int chatId;
  final String chatTitle;
  final int myUserId;
  final String callId;
  final int startedByUserId;
  final Map<int, String> memberNames;
  final ChatSocketService? existingSocket;
  final bool isHost;
  final bool startWithVideo;
  final Map<String, dynamic>? incomingInvite;

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  late ChatSocketService _socket;
  bool _ownsSocket = false;
  GroupCallSession? _session;
  String _status = 'Подключение…';
  int _participantCount = 1;
  bool _micOn = true;
  bool _camOn = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Групповые звонки в браузере пока не поддерживаются'),
          ),
        );
        Navigator.of(context).pop();
      });
      return;
    }
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final existing = widget.existingSocket;
    if (existing != null && existing.isConnected) {
      _socket = existing;
      _ownsSocket = false;
    } else {
      _socket = ChatSocketService();
      _ownsSocket = true;
      try {
        await _socket.connect(
          chatId: widget.chatId,
          baseHttpUrl: ApiClient.baseUrl,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _status = 'Нет соединения с сервером');
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    final session = GroupCallSession(
      callId: widget.callId,
      chatId: widget.chatId,
      myUserId: widget.myUserId,
      startedByUserId: widget.startedByUserId,
      send: (m) => _socket.sendJson(m),
      socketStream: _socket.messagesStream,
      onStatus: (s) {
        if (mounted) setState(() => _status = s);
      },
      onParticipantCount: (n) {
        if (mounted) setState(() => _participantCount = n);
      },
      onEnded: () {
        if (mounted) Navigator.of(context).maybePop();
      },
      startWithVideo: widget.startWithVideo,
      isHost: widget.isHost,
    );

    if (!GroupCallSession.tryAcquire(session)) {
      if (!mounted) return;
      setState(() => _status = 'Уже есть активный звонок');
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _session = session;
      _camOn = widget.startWithVideo;
    });

    await session.run();
    if (mounted) {
      setState(() {
        _camOn = session.cameraOn;
      });
    }
  }

  @override
  void dispose() {
    final s = _session;
    unawaited(s?.dispose() ?? Future<void>.value());
    if (_ownsSocket) {
      unawaited(_socket.disconnect());
    }
    super.dispose();
  }

  String _nameFor(int userId) {
    final n = widget.memberNames[userId];
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return 'Участник $userId';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => session?.leave(),
                        icon: const Icon(
                          AppIcons.close,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.chatTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$_participantCount ${_participantCount == 1 ? 'участник' : 'участников'} · $_status',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: session == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        )
                      : ValueListenableBuilder<int>(
                          valueListenable: session.meshVersion,
                          builder: (context, _, __) {
                            final remotes = session.remoteVideoRenderers;
                            final keys = remotes.keys.toList()..sort();
                            if (keys.isEmpty && !session.cameraOn) {
                              return const Center(
                                child: Text(
                                  'Ожидаем участников…',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.72,
                              ),
                              itemCount: keys.length + (session.cameraOn ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (session.cameraOn && i == 0) {
                                  return _VideoTile(
                                    label: 'Вы',
                                    renderer: session.localRenderer,
                                    mirror: true,
                                  );
                                }
                                final idx =
                                    session.cameraOn ? i - 1 : i;
                                final uid = keys[idx];
                                final r = remotes[uid]!;
                                return _VideoTile(
                                  label: _nameFor(uid),
                                  renderer: r,
                                  mirror: false,
                                );
                              },
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceSoft,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        onPressed: session == null
                            ? null
                            : () {
                                setState(() {
                                  _micOn = !_micOn;
                                  session.setMicEnabled(_micOn);
                                });
                              },
                        icon: Icon(_micOn ? AppIcons.mic : AppIcons.micOff),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceSoft,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        onPressed: session == null
                            ? null
                            : () async {
                                final next = !_camOn;
                                setState(() => _camOn = next);
                                await session.setCameraEnabled(next);
                                if (mounted) {
                                  setState(() => _camOn = session.cameraOn);
                                }
                              },
                        icon: Icon(
                          _camOn ? Icons.videocam : Icons.videocam_off,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceSoft,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        onPressed: (session == null || !_camOn)
                            ? null
                            : () => session.switchCamera(),
                        icon: const Icon(Icons.cameraswitch),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            session == null ? null : () => session.leave(),
                        icon: const Icon(AppIcons.callEnd),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (session != null && !session.cameraOn)
              Positioned(
                left: 0,
                right: 0,
                bottom: 88,
                height: 64,
                child: ValueListenableBuilder<int>(
                  valueListenable: session.meshVersion,
                  builder: (context, _, __) {
                    final remotes = session.remoteVideoRenderers;
                    if (remotes.isEmpty) return const SizedBox.shrink();
                    return Opacity(
                      opacity: 0,
                      child: Row(
                        children: remotes.entries
                            .map(
                              (e) => SizedBox(
                                width: 64,
                                height: 64,
                                child: RTCVideoView(
                                  e.value,
                                  mirror: false,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.label,
    required this.renderer,
    required this.mirror,
  });

  final String label;
  final RTCVideoRenderer renderer;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.35),
            child: RTCVideoView(
              renderer,
              mirror: mirror,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
}
