import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../core/network/api_client.dart';
import '../../../chats/data/services/chat_socket_service.dart';
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {
                    session?.hangUp();
                  },
                  icon: const Icon(AppIcons.close, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.peerTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
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
              if (session != null)
                SizedBox(
                  height: 1,
                  width: 1,
                  child: RTCVideoView(
                    session.remoteRenderer,
                    mirror: false,
                  ),
                ),
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
                  const SizedBox(width: 28),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: session == null
                        ? null
                        : () => session.hangUp(),
                    icon: const Icon(AppIcons.callEnd),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
