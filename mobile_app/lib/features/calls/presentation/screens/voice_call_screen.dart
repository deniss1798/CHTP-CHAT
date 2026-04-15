import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../core/network/api_client.dart';
import '../../../chats/data/services/chat_socket_service.dart';
import '../../../chats/data/services/messages_service.dart';
import '../../data/voice_call_session.dart';

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
  });

  final int chatId;
  final String peerTitle;
  final int peerUserId;
  final int myUserId;
  final ChatSocketService? existingSocket;
  final Map<String, dynamic>? incomingInit;

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
  final MessagesService _messagesService = MessagesService();

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
        if (mounted) Navigator.of(context).maybePop();
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
  }

  String _newCallId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${widget.myUserId}_${widget.peerUserId}';
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (session != null)
              RTCVideoView(
                session.remoteRenderer,
                mirror: false,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              const ColoredBox(color: AppColors.background),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        session?.hangUp();
                      },
                      icon:
                          const Icon(AppIcons.close, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.peerTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Аудио: DTLS-SRTP. Сигналинг: X25519 + AES-GCM.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (session != null && _camOn)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 110,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: RTCVideoView(
                            session.localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
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
                                  setState(() => _camOn = session.isCameraOn);
                                }
                              },
                        icon: Icon(_camOn ? Icons.videocam : Icons.videocam_off),
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
                        onPressed: session == null ? null : () => session.hangUp(),
                        icon: const Icon(AppIcons.callEnd),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // На десктопе слишком малый виджет иногда глушит воспроизведение удалённого аудио.
                  if (session != null)
                    Opacity(
                      opacity: 0,
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: RTCVideoView(
                          session.remoteRenderer,
                          mirror: false,
                        ),
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
