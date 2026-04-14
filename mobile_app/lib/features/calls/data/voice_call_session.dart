import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_signaling_crypto.dart';

const _callSignalTypes = {
  'call_e2e_init',
  'call_e2e_ack',
  'call_e2e_offer',
  'call_e2e_answer',
  'call_e2e_ice',
  'call_e2e_hangup',
};

/// Один активный звонок на процесс.
class VoiceCallSession {
  VoiceCallSession({
    required this.callId,
    required this.chatId,
    required this.myUserId,
    required this.peerUserId,
    required this.send,
    required this.socketStream,
    required this.onStatus,
    required this.onEnded,
    required this.isCaller,
    this.remoteCallerPubB64,
  });

  static VoiceCallSession? _active;

  static bool tryAcquire(VoiceCallSession s) {
    if (_active != null) return false;
    _active = s;
    return true;
  }

  static void release() {
    _active = null;
  }

  final String callId;
  final int chatId;
  final int myUserId;
  final int peerUserId;
  final void Function(Map<String, dynamic> payload) send;
  final Stream<Map<String, dynamic>> socketStream;
  final void Function(String status) onStatus;
  final VoidCallback onEnded;
  final bool isCaller;

  /// Для входящего: публичный ключ звонящего из [call_e2e_init].
  final String? remoteCallerPubB64;

  CallSignalingCrypto? _crypto;
  SecretKey? _signalingKey;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  StreamSubscription<Map<String, dynamic>>? _socketSub;

  final Completer<void> _callerAck = Completer<void>();

  bool _ended = false;
  bool _answerSent = false;
  String? _pendingOfferPayload;

  Future<void> run() async {
    if (kIsWeb) {
      onStatus('Звонки в браузере не поддерживаются');
      return;
    }

    await remoteRenderer.initialize();

    _socketSub = socketStream.listen(_onSocketMessage, onError: (_) {});

    if (isCaller) {
      await _runCaller();
    } else {
      await _runCallee();
    }
  }

  Future<void> _runCaller() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      onStatus('Нет доступа к микрофону');
      _finish(notify: true);
      return;
    }

    onStatus('Соединение…');
    _crypto = await CallSignalingCrypto.generate();
    final pub = await _crypto!.publicKeyBase64();
    send({
      'type': 'call_e2e_init',
      'call_id': callId,
      'ephem_pub_b64': pub,
    });

    try {
      await _callerAck.future.timeout(const Duration(seconds: 45));
    } catch (_) {
      onStatus('Нет ответа');
      _sendHangup();
      _finish(notify: true);
      return;
    }

    if (_ended) return;

    onStatus('Вызов…');

    try {
      await _openMicAndPeer();
      final offer = await _pc!.createOffer({'offerToReceiveAudio': true});
      await _pc!.setLocalDescription(offer);
      final blob = await _crypto!.encryptString(_signalingKey!, jsonEncode({
        'type': offer.type,
        'sdp': offer.sdp,
      }));
      send({
        'type': 'call_e2e_offer',
        'call_id': callId,
        'payload': blob,
      });
    } catch (e) {
      onStatus('Ошибка: $e');
      _sendHangup();
      _finish(notify: true);
    }
  }

  Future<void> _runCallee() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      onStatus('Нет доступа к микрофону');
      _sendHangup();
      _finish(notify: true);
      return;
    }

    if (remoteCallerPubB64 == null || remoteCallerPubB64!.isEmpty) {
      onStatus('Некорректный звонок');
      _sendHangup();
      _finish(notify: true);
      return;
    }

    onStatus('Подключение…');

    _crypto = await CallSignalingCrypto.generate();
    _signalingKey =
        await _crypto!.deriveSharedSecret(remoteCallerPubB64!);

    final pub = await _crypto!.publicKeyBase64();
    send({
      'type': 'call_e2e_ack',
      'call_id': callId,
      'ephem_pub_b64': pub,
    });

    try {
      await _openMicAndPeer();
    } catch (e) {
      onStatus('Ошибка: $e');
      _sendHangup();
      _finish(notify: true);
      return;
    }

    final pending = _pendingOfferPayload;
    if (pending != null) {
      _pendingOfferPayload = null;
      await _onOffer(pending);
    }

    onStatus('Соединение…');
  }

  Future<void> _openMicAndPeer() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
      },
      'video': false,
    });
    _localStream = stream;

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    final pc = await createPeerConnection(config);
    _pc = pc;

    pc.onIceCandidate = (RTCIceCandidate? c) {
      if (_ended || c == null || _signalingKey == null || _crypto == null) {
        return;
      }
      unawaited(_sendIceCandidate(c));
    };

    pc.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        remoteRenderer.srcObject = e.streams[0];
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState s) {
      if (_ended) return;
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onStatus('В эфире');
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (!_ended) {
          onStatus('Соединение прервано');
        }
      }
    };

    for (final t in stream.getAudioTracks()) {
      await pc.addTrack(t, stream);
    }
  }

  Future<void> _sendIceCandidate(RTCIceCandidate c) async {
    try {
      final json = jsonEncode({
        'c': c.candidate,
        'm': c.sdpMid,
        'i': c.sdpMLineIndex,
      });
      final blob = await _crypto!.encryptString(_signalingKey!, json);
      send({
        'type': 'call_e2e_ice',
        'call_id': callId,
        'payload': blob,
      });
    } catch (_) {}
  }

  void _onSocketMessage(Map<String, dynamic> msg) {
    if (_ended) return;
    final t = msg['type']?.toString();
    if (t == null || !_callSignalTypes.contains(t)) return;

    final uid = _int(msg['user_id']);
    if (uid == null || uid != peerUserId) return;

    final cid = msg['call_id']?.toString();
    if (cid == null || cid != callId) return;

    switch (t) {
      case 'call_e2e_ack':
        if (!isCaller || _callerAck.isCompleted) return;
        final remotePub = msg['ephem_pub_b64']?.toString();
        if (remotePub == null || remotePub.isEmpty) return;
        unawaited(_onAck(remotePub));
        break;
      case 'call_e2e_offer':
        if (isCaller) return;
        final payload = msg['payload']?.toString();
        if (payload == null) return;
        unawaited(_onOffer(payload));
        break;
      case 'call_e2e_answer':
        if (!isCaller) return;
        final payload = msg['payload']?.toString();
        if (payload == null) return;
        unawaited(_onAnswer(payload));
        break;
      case 'call_e2e_ice':
        final payload = msg['payload']?.toString();
        if (payload == null) return;
        unawaited(_onIce(payload));
        break;
      case 'call_e2e_hangup':
        onStatus('Собеседник завершил звонок');
        _finish(notify: true);
        break;
      default:
        break;
    }
  }

  Future<void> _onAck(String remotePub) async {
    try {
      _signalingKey = await _crypto!.deriveSharedSecret(remotePub);
      if (!_callerAck.isCompleted) {
        _callerAck.complete();
      }
    } catch (e) {
      onStatus('Ошибка ключа: $e');
      _sendHangup();
      _finish(notify: true);
    }
  }

  Future<void> _onOffer(String blob) async {
    if (_answerSent) return;
    if (_signalingKey == null || _crypto == null) {
      return;
    }
    if (_pc == null) {
      _pendingOfferPayload = blob;
      return;
    }
    try {
      final plain = await _crypto!.decryptString(_signalingKey!, blob);
      final map = jsonDecode(plain) as Map<String, dynamic>;
      final sdp = map['sdp']?.toString();
      final typ = map['type']?.toString();
      if (sdp == null || typ == null) return;

      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, typ));
      final answer = await _pc!.createAnswer({'offerToReceiveAudio': true});
      await _pc!.setLocalDescription(answer);
      final out = await _crypto!.encryptString(_signalingKey!, jsonEncode({
        'type': answer.type,
        'sdp': answer.sdp,
      }));
      send({
        'type': 'call_e2e_answer',
        'call_id': callId,
        'payload': out,
      });
      _answerSent = true;
    } catch (e) {
      onStatus('Ошибка ответа: $e');
      _sendHangup();
      _finish(notify: true);
    }
  }

  Future<void> _onAnswer(String blob) async {
    if (_pc == null || _signalingKey == null || _crypto == null) return;
    try {
      final plain = await _crypto!.decryptString(_signalingKey!, blob);
      final map = jsonDecode(plain) as Map<String, dynamic>;
      final sdp = map['sdp']?.toString();
      final typ = map['type']?.toString();
      if (sdp == null || typ == null) return;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, typ));
    } catch (e) {
      onStatus('Ошибка: $e');
      _sendHangup();
      _finish(notify: true);
    }
  }

  Future<void> _onIce(String blob) async {
    if (_pc == null || _signalingKey == null || _crypto == null) return;
    try {
      final plain = await _crypto!.decryptString(_signalingKey!, blob);
      final map = jsonDecode(plain) as Map<String, dynamic>;
      final cand = map['c']?.toString();
      if (cand == null) return;
      final mid = map['m']?.toString();
      final idxRaw = map['i'];
      int? idx;
      if (idxRaw is int) {
        idx = idxRaw;
      } else {
        idx = int.tryParse(idxRaw?.toString() ?? '');
      }
      await _pc!.addCandidate(RTCIceCandidate(cand, mid, idx));
    } catch (_) {}
  }

  void _sendHangup() {
    send({
      'type': 'call_e2e_hangup',
      'call_id': callId,
    });
  }

  void hangUp() {
    if (_ended) return;
    _sendHangup();
    _finish(notify: true);
  }

  void setMicEnabled(bool on) {
    final s = _localStream;
    if (s == null) return;
    for (final t in s.getAudioTracks()) {
      t.enabled = on;
    }
  }

  void _finish({bool notify = true}) {
    if (_ended) return;
    _ended = true;
    try {
      _socketSub?.cancel();
    } catch (_) {}
    _socketSub = null;

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _localStream = null;

    try {
      _pc?.close();
    } catch (_) {}
    _pc = null;

    try {
      remoteRenderer.srcObject = null;
    } catch (_) {}

    if (notify) {
      onEnded();
    }
  }

  Future<void> dispose() async {
    if (!_ended) {
      _sendHangup();
    }
    _finish(notify: false);
    try {
      await remoteRenderer.dispose();
    } catch (_) {}
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }
}
