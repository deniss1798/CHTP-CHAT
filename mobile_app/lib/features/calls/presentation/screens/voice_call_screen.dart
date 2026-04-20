import 'dart:async';

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
import '../../../chats/data/services/messages_service.dart';
import '../../data/voice_call_session.dart';
import '../widgets/call_participant_tile.dart';

/// Голосовой звонок 1:1: WebRTC (DTLS-SRTP) + зашифрованный сигналинг (X25519 + AES-GCM).
class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({
    super.key,
    required this.chatId,
    required this.peerTitle,
    required this.peerUserId,
    required this.myUserId,
    this.existingSocket,
    this.incomingInit,
    this.peerAvatarUrl,
    this.myAvatarUrl,
  });

  final int chatId;
  final String peerTitle;
  final int peerUserId;
  final int myUserId;
  final ChatSocketService? existingSocket;
  final Map<String, dynamic>? incomingInit;
  final String? peerAvatarUrl;
  final String? myAvatarUrl;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late ChatSocketService _socket;
  bool _ownsSocket = false;
  VoiceCallSession? _session;
  String _status = '…';
  bool _micOn = true;
  bool _camOn = false;

  /// После завершения звонка нужно временно разрешить pop — иначе [PopScope](canPop: false) блокирует [Navigator.pop].
  bool _allowRoutePop = false;
  DateTime? _lastTrackUiBump;
  Timer? _remoteVideoUiPoll;
  bool? _lastRemoteVideoLive;
  final MessagesService _messagesService = MessagesService();

  void _startRemoteVideoUiPoll() {
    _remoteVideoUiPoll?.cancel();
    _lastRemoteVideoLive = null;
    _remoteVideoUiPoll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      final s = _session;
      if (s == null) return;
      final live =
          CallParticipantTile.rendererHasLiveVideo(s.remoteRenderer);
      if (_lastRemoteVideoLive == live) return;
      _lastRemoteVideoLive = live;
      setState(() {});
    });
  }

  void _stopRemoteVideoUiPoll() {
    _remoteVideoUiPoll?.cancel();
    _remoteVideoUiPoll = null;
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Голосовые звонки в браузере пока не поддерживаются'),
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

    final incoming = widget.incomingInit;
    final isCallee = incoming != null;
    final callId = isCallee
        ? (incoming['call_id']?.toString() ?? '')
        : _newCallId();
    if (isCallee && callId.isEmpty) {
      if (!mounted) return;
      setState(() => _status = 'Некорректный звонок');
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final session = VoiceCallSession(
      callId: callId,
      chatId: widget.chatId,
      myUserId: widget.myUserId,
      peerUserId: widget.peerUserId,
      send: (m) => _socket.sendJson(m),
      socketStream: _socket.messagesStream,
      onStatus: (s) {
        if (mounted) setState(() => _status = s);
      },
      onEnded: () {
        if (!mounted) return;
        setState(() => _allowRoutePop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pop();
        });
      },
      isCaller: !isCallee,
      remoteCallerPubB64: incoming?['ephem_pub_b64']?.toString(),
      onChatMessage: (text) {
        unawaited(
          _messagesService.sendMessage(chatId: widget.chatId, text: text).then(
                (_) {},
                onError: (_) {},
              ),
        );
      },
      onTracksChanged: () {
        if (!mounted) return;
        final now = DateTime.now();
        if (_lastTrackUiBump != null &&
            now.difference(_lastTrackUiBump!) <
                const Duration(milliseconds: 300)) {
          return;
        }
        _lastTrackUiBump = now;
        setState(() {});
      },
    );

    if (!VoiceCallSession.tryAcquire(session)) {
      if (!mounted) return;
      setState(() => _status = 'Уже есть активный звонок');
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _session = session;
      _camOn = session.isCameraOn;
    });

    await session.run();
    if (mounted) _startRemoteVideoUiPoll();
  }

  String _newCallId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${widget.myUserId}_${widget.peerUserId}';
  }

  @override
  void dispose() {
    _stopRemoteVideoUiPoll();
    final s = _session;
    unawaited(s?.dispose() ?? Future<void>.value());
    VoiceCallSession.release();
    if (_ownsSocket) {
      unawaited(_socket.disconnect());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _session?.hangUp();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AppScreenBackground(
          child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    AppIconButtonSurface(
                      icon: AppIcons.close,
                      tooltip: 'Завершить',
                      onTap: () => session?.hangUp(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const AppPillBadge(label: 'PRIVATE CALL', accent: true),
                          const SizedBox(height: 8),
                          Text(
                            widget.peerTitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: session == null
                    ? const ColoredBox(color: AppColors.background)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: CallParticipantTile(
                                label: 'Вы',
                                renderer: session.localRenderer,
                                avatarUrl: widget.myAvatarUrl,
                                showVideo: _camOn,
                                mirror: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CallParticipantTile(
                                label: widget.peerTitle,
                                renderer: session.remoteRenderer,
                                avatarUrl: widget.peerAvatarUrl,
                                showVideo: true,
                                mirror: false,
                                attachHiddenVideoSurface: true,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: AppSurface(
                  radius: AppRadius.pill,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                  setState(() => _camOn = session.isCameraOn);
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
                          onPressed: session == null ? null : () => session.hangUp(),
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
