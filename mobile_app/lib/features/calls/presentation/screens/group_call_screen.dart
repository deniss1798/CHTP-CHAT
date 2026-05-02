import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../core/network/api_client.dart';
import '../../../chats/data/services/chat_socket_service.dart';
import '../../../chats/data/services/chats_service.dart';
import '../../data/group_call_session.dart';
import '../widgets/call_participant_tile.dart';

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
    this.memberAvatarUrls,
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
  final Map<int, String?>? memberAvatarUrls;
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
  String _status = 'Соединение…';
  bool _micOn = true;
  bool _camOn = false;
  bool _allowRoutePop = false;

  late Map<int, String> _memberNames;
  late Map<int, String?> _memberAvatars;

  @override
  void initState() {
    super.initState();
    _memberNames = Map<int, String>.from(widget.memberNames);
    _memberAvatars = widget.memberAvatarUrls != null
        ? Map<int, String?>.from(widget.memberAvatarUrls!)
        : <int, String?>{};
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
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    try {
      final roster = await ChatsService().loadChatMembersRoster(widget.chatId);
      if (mounted) {
        setState(() {
          for (final e in roster.names.entries) {
            _memberNames[e.key] = e.value;
          }
          for (final e in roster.avatars.entries) {
            _memberAvatars[e.key] = e.value;
          }
        });
      }
    } catch (_) {}

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
      onParticipantCount: (_) {},
      onEnded: () {
        if (!mounted) return;
        setState(() => _allowRoutePop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pop();
        });
      },
      startWithVideo: widget.startWithVideo,
      isHost: widget.isHost,
    );

    if (!GroupCallSession.tryAcquire(session)) {
      if (!mounted) return;
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
    final n = _memberNames[userId];
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return 'Участник $userId';
  }

  String? _avatarForUser(int userId) {
    return _memberAvatars[userId];
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _session?.leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AppScreenBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ЧТП ЧАТ',
                          style: TextStyle(
                            color: AppColors.accentBright,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppIconButtonSurface(
                            icon: AppIcons.back,
                            tooltip: 'Назад',
                            onTap: () => session?.leave(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  widget.chatTitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    height: 1.25,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _status,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    color: AppColors.accentBright,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSurface(
                            radius: AppRadius.pill,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: AppColors.accentBright,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Защищённый звонок',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: session == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        )
                      : ValueListenableBuilder<int>(
                          valueListenable: session.meshVersion,
                          builder: (context, meshTick, _) {
                            final remotes = session.remoteVideoRenderers;
                            final keys = remotes.keys.toList()..sort();
                            final n = keys.length + 1;
                            final cols = n <= 1
                                ? 1
                                : math.min(4, math.max(2, math.sqrt(n).ceil()));

                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.92,
                              ),
                              itemCount: n,
                              itemBuilder: (context, i) {
                                if (i == 0) {
                                  return CallParticipantTile(
                                    key: const ValueKey<String>(
                                        'group_tile_local'),
                                    label: 'Вы',
                                    renderer: session.localRenderer,
                                    avatarUrl: _avatarForUser(widget.myUserId),
                                    showVideo: _camOn,
                                    mirror: true,
                                  );
                                }
                                final uid = keys[i - 1];
                                final r = remotes[uid]!;
                                return CallParticipantTile(
                                  key: ValueKey<int>(uid),
                                  label: _nameFor(uid),
                                  renderer: r,
                                  avatarUrl: _avatarForUser(uid),
                                  showVideo: true,
                                  mirror: false,
                                  attachHiddenVideoSurface: true,
                                );
                              },
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: AppSurface(
                    radius: AppRadius.pill,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIconButtonSurface(
                          icon: _micOn ? AppIcons.mic : AppIcons.micOff,
                          active: _micOn,
                          onTap: session == null
                              ? null
                              : () {
                                  setState(() {
                                    _micOn = !_micOn;
                                    session.setMicEnabled(_micOn);
                                  });
                                },
                        ),
                        const SizedBox(width: 12),
                        AppIconButtonSurface(
                          icon: _camOn ? AppIcons.videocam : AppIcons.videocamOff,
                          active: _camOn,
                          onTap: session == null
                              ? null
                              : () async {
                                  final next = !_camOn;
                                  setState(() => _camOn = next);
                                  await session.setCameraEnabled(next);
                                  if (mounted) {
                                    setState(() => _camOn = session.cameraOn);
                                  }
                                },
                        ),
                        const SizedBox(width: 12),
                        AppIconButtonSurface(
                          icon: Icons.cameraswitch_rounded,
                          onTap: (session == null || !_camOn)
                              ? null
                              : () => session.switchCamera(),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE34B3F), Color(0xFFB7201B)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.primaryButton,
                          ),
                          child: IconButton(
                            onPressed:
                                session == null ? null : () => session.leave(),
                            icon: const Icon(AppIcons.callEnd, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
