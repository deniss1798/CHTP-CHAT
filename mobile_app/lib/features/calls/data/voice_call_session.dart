import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, VoidCallback, defaultTargetPlatform, kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../call_chat_message.dart';
import '../call_coordinator.dart';
import 'call_signaling_crypto.dart';
import 'ice_config_service.dart';
import 'webrtc_render_bind.dart';
import 'webrtc_video_constraints.dart';

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
    this.onChatMessage,
    this.onTracksChanged,
  });

  static VoiceCallSession? _active;

  static bool tryAcquire(VoiceCallSession s) {
    final cur = _active;
    if (cur != null && cur._ended) {
      release();
    }
    if (_active != null || !CallCoordinator.tryEnterVoice()) return false;
    _active = s;
    return true;
  }

  static void release() {
    if (_active != null) {
      CallCoordinator.exitVoice();
    }
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

  /// Строка в чат после завершения звонка (длительность / отклонён / отменён).
  final void Function(String text)? onChatMessage;

  /// Вызывается при смене удалённых/локальных дорожек (обновить превью video/avatar).
  final VoidCallback? onTracksChanged;

  CallSignalingCrypto? _crypto;
  SecretKey? _signalingKey;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _cameraStream;
  MediaStreamTrack? _localVideoTrack;
  bool _cameraOn = false;

  /// Один поток на удалённую сторону: при onTrack без streams сначала приходит audio, потом video —
  /// иначе видео затирается или теряется.
  MediaStream? _remoteCombinedStream;

  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  StreamSubscription<Map<String, dynamic>>? _socketSub;

  final Completer<void> _callerAck = Completer<void>();

  bool _ended = false;
  bool _answerSent = false;
  String? _pendingOfferPayload;
  bool _hadP2PConnected = false;
  DateTime? _connectedAt;

  /// До setRemoteDescription кандидаты нельзя добавлять — иначе ICE теряется.
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingRemoteIce = [];

  Future<void> run() async {
    if (kIsWeb) {
      onStatus('Звонки в браузере не поддерживаются');
      return;
    }

    await remoteRenderer.initialize();
    await localRenderer.initialize();

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
      _finish(notify: true, kind: CallEndKind.error);
      return;
    }

    onStatus('Звоним…');
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
      _finish(notify: true, kind: CallEndKind.ackTimeout);
      return;
    }

    if (_ended) return;

    onStatus('Соединение…');

    try {
      await _openMicAndPeer();
      await _renegotiateAndSendOffer();
    } catch (e) {
      onStatus('Ошибка: $e');
      _sendHangup();
      _finish(notify: true, kind: CallEndKind.error);
    }
  }

  Future<void> _runCallee() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      onStatus('Нет доступа к микрофону');
      _sendHangup();
      _finish(notify: true, kind: CallEndKind.error);
      return;
    }

    if (remoteCallerPubB64 == null || remoteCallerPubB64!.isEmpty) {
      onStatus('Некорректный звонок');
      _sendHangup();
      _finish(notify: true, kind: CallEndKind.error);
      return;
    }

    onStatus('Соединение…');

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
      _finish(notify: true, kind: CallEndKind.error);
      return;
    }

    final pending = _pendingOfferPayload;
    if (pending != null) {
      _pendingOfferPayload = null;
      await _onOffer(pending);
    }
  }

  Future<void> _openMicAndPeer() async {
    final camOk = await Permission.camera.request();
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
      },
      'video': camOk.isGranted ? webrtcVideoCaptureConstraints() : false,
    });
    _localStream = stream;
    for (final vt in stream.getVideoTracks()) {
      vt.enabled = false;
    }
    _cameraOn = false;
    _localVideoTrack =
        stream.getVideoTracks().isNotEmpty ? stream.getVideoTracks().first : null;

    final config = <String, dynamic>{
      'iceServers': await resolveIceServerConfig(),
      'sdpSemantics': 'unified-plan',
    };
    // Debug: --dart-define=WEBRTC_FORCE_RELAY=true forces TURN-only (no direct P2P).
    // If calls work with relay, host/srflx path was failing, not the TURN server itself.
    const forceRelay =
        bool.fromEnvironment('WEBRTC_FORCE_RELAY', defaultValue: false);
    if (forceRelay) {
      config['iceTransportPolicy'] = 'relay';
    }
    final pc = await createPeerConnection(config);
    _pc = pc;
    _remoteDescriptionSet = false;

    pc.onIceCandidate = (RTCIceCandidate? c) {
      if (_ended || c == null || _signalingKey == null || _crypto == null) {
        return;
      }
      unawaited(_sendIceCandidate(c));
    };

    pc.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        final s = e.streams[0];
        for (final t in s.getTracks()) {
          t.enabled = true;
        }
        _remoteCombinedStream = s;
        bindRtcVideoRenderer(remoteRenderer, s);
        _attachRemoteVideoUiListeners(s);
        try {
          onTracksChanged?.call();
        } catch (_) {}
      } else {
        unawaited(_mergeRemoteTrackWithoutStreams(e.track));
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState s) {
      if (_ended) return;
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _hadP2PConnected = true;
        _connectedAt ??= DateTime.now();
        onStatus('В эфире');
        // На desktop переключение «динамик» может обрубить вывод; только Android/iOS.
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)) {
          unawaited(() async {
            try {
              await Helper.setSpeakerphoneOn(true);
            } catch (_) {}
          }());
        }
        return;
      }
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (!_ended) {
          onStatus('Соединение прервано');
        }
        return;
      }
      // Disconnected без успешного Connected часто бывает при ICE до готовности — не путаем с обрывом звонка.
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected &&
          _hadP2PConnected &&
          !_ended) {
        onStatus('Соединение прервано');
      }
    };

    for (final t in stream.getTracks()) {
      await pc.addTrack(t, stream);
    }
    try {
      bindRtcVideoRenderer(localRenderer, stream);
    } catch (_) {}
  }

  /// Когда собеседник включает/выключает камеру, снова [onTrack] не приходит — дергаем UI.
  void _attachRemoteVideoUiListeners(MediaStream s) {
    for (final t in s.getVideoTracks()) {
      t.onUnMute = () {
        try {
          onTracksChanged?.call();
        } catch (_) {}
      };
      t.onMute = () {
        try {
          onTracksChanged?.call();
        } catch (_) {}
      };
    }
    for (final t in s.getAudioTracks()) {
      t.onUnMute = () {
        try {
          onTracksChanged?.call();
        } catch (_) {}
      };
      t.onMute = () {
        try {
          onTracksChanged?.call();
        } catch (_) {}
      };
    }
  }

  bool get isCameraOn => _cameraOn;

  Future<void> setCameraEnabled(bool on) async {
    if (_ended) return;
    if (on == _cameraOn) return;

    final pc = _pc;
    final local = _localStream;
    if (pc == null || local == null) return;

    final vts = List<MediaStreamTrack>.from(local.getVideoTracks());
    if (vts.isNotEmpty) {
      for (final t in vts) {
        t.enabled = on;
      }
      _cameraOn = on;
      _localVideoTrack = vts.first;
      try {
        bindRtcVideoRenderer(localRenderer, local);
      } catch (_) {}
      try {
        onTracksChanged?.call();
      } catch (_) {}
      return;
    }

    if (!on) return;

    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      onStatus('Нет доступа к камере');
      return;
    }
    try {
      final camStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': webrtcVideoCaptureConstraints(),
      });
      _cameraStream = camStream;
      final vt = camStream.getVideoTracks().isNotEmpty
          ? camStream.getVideoTracks().first
          : null;
      if (vt == null) {
        onStatus('Камера недоступна');
        try {
          camStream.getTracks().forEach((t) => t.stop());
        } catch (_) {}
        _cameraStream = null;
        return;
      }
      _localVideoTrack = vt;
      await local.addTrack(vt);
      await pc.addTrack(vt, local);
      bindRtcVideoRenderer(localRenderer, local);
      _cameraOn = true;
      await _renegotiateAndSendOffer();
      try {
        onTracksChanged?.call();
      } catch (_) {}
    } catch (e) {
      onStatus('Ошибка камеры: $e');
      await _stopLocalCameraTracks();
    }
  }

  Future<void> switchCamera() async {
    final t = _localVideoTrack;
    if (t == null) return;
    try {
      await Helper.switchCamera(t);
    } catch (_) {}
  }

  Future<void> _stopLocalCameraTracks() async {
    final local = _localStream;
    final t = _localVideoTrack;
    _localVideoTrack = null;

    try {
      if (local != null && t != null) {
        await local.removeTrack(t);
      }
    } catch (_) {}

    try {
      t?.stop();
    } catch (_) {}

    try {
      final cs = _cameraStream;
      _cameraStream = null;
      cs?.getTracks().forEach((x) => x.stop());
    } catch (_) {}
  }

  Future<void> _renegotiate() async {
    final pc = _pc;
    if (pc == null || _ended) return;
    try {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
        'voiceActivityDetection': true,
      });
      await pc.setLocalDescription(offer);
    } catch (_) {}
  }

  Future<void> _renegotiateAndSendOffer() async {
    if (_ended) return;
    final pc = _pc;
    final key = _signalingKey;
    final crypto = _crypto;
    if (pc == null || key == null || crypto == null) return;
    await _renegotiate();
    try {
      final ld = await pc.getLocalDescription();
      if (ld?.sdp == null || ld!.sdp!.isEmpty) return;
      final blob = await crypto.encryptString(key, jsonEncode({
        'type': ld.type,
        'sdp': ld.sdp,
      }));
      send({
        'type': 'call_e2e_offer',
        'call_id': callId,
        'payload': blob,
      });
    } catch (_) {}
  }

  /// На части платформ в [RTCTrackEvent.streams] пусто; дорожки приходят по одной (audio, затем video).
  Future<void> _mergeRemoteTrackWithoutStreams(MediaStreamTrack track) async {
    if (_ended) return;
    if (track.kind != 'audio' && track.kind != 'video') return;
    try {
      track.enabled = true;
      var ms = _remoteCombinedStream ?? remoteRenderer.srcObject;
      if (ms == null) {
        ms = await createLocalMediaStream('remote-$peerUserId');
        _remoteCombinedStream = ms;
        bindRtcVideoRenderer(remoteRenderer, ms);
      } else {
        _remoteCombinedStream = ms;
      }
      var already = false;
      for (final t in ms.getTracks()) {
        if (t.id == track.id) {
          already = true;
          break;
        }
      }
      if (!already) {
        await ms.addTrack(track);
      }
      bindRtcVideoRenderer(remoteRenderer, ms);
      _attachRemoteVideoUiListeners(ms);
      try {
        onTracksChanged?.call();
      } catch (_) {}
    } catch (_) {}
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
        final payload = msg['payload']?.toString();
        if (payload == null) return;
        unawaited(_onOffer(payload));
        break;
      case 'call_e2e_answer':
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
        _finish(notify: true, kind: CallEndKind.remoteHangup);
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
      _finish(notify: true, kind: CallEndKind.error);
    }
  }

  Future<void> _onOffer(String blob) async {
    if (_signalingKey == null || _crypto == null) {
      return;
    }
    if (_pc == null) {
      _pendingOfferPayload = blob;
      return;
    }
    await _handleOfferWithRetry(blob);
  }

  Future<void> _handleOfferWithRetry(String blob) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (_ended) return;
      final pc = _pc;
      if (pc == null) return;
      if (pc.signalingState ==
          RTCSignalingState.RTCSignalingStateStable) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (_ended) return;
    final pc = _pc;
    if (pc == null) return;
    try {
      final plain = await _crypto!.decryptString(_signalingKey!, blob);
      final map = jsonDecode(plain) as Map<String, dynamic>;
      final sdp = map['sdp']?.toString();
      final typ = map['type']?.toString();
      if (sdp == null || typ == null) return;

      await pc.setRemoteDescription(RTCSessionDescription(sdp, typ));
      _remoteDescriptionSet = true;
      await _flushPendingIce();
      final answer = await pc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
        'voiceActivityDetection': true,
      });
      await pc.setLocalDescription(answer);
      final ld = await pc.getLocalDescription();
      final out = await _crypto!.encryptString(_signalingKey!, jsonEncode({
        'type': ld?.type,
        'sdp': ld?.sdp,
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
      _finish(notify: true, kind: CallEndKind.error);
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
      _remoteDescriptionSet = true;
      await _flushPendingIce();
    } catch (e) {
      onStatus('Ошибка: $e');
      _sendHangup();
      _finish(notify: true, kind: CallEndKind.error);
    }
  }

  Future<void> _flushPendingIce() async {
    final pc = _pc;
    if (pc == null || !_remoteDescriptionSet) return;
    final batch = List<RTCIceCandidate>.from(_pendingRemoteIce);
    _pendingRemoteIce.clear();
    for (final c in batch) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
  }

  Future<void> _onIce(String blob) async {
    if (_pc == null || _signalingKey == null || _crypto == null) return;
    try {
      final plain = await _crypto!.decryptString(_signalingKey!, blob);
      final map = jsonDecode(plain) as Map<String, dynamic>;
      final cand = map['c']?.toString();
      if (cand == null || cand.isEmpty) {
        return;
      }
      final mid = map['m']?.toString();
      final idxRaw = map['i'];
      int? idx;
      if (idxRaw is int) {
        idx = idxRaw;
      } else {
        idx = int.tryParse(idxRaw?.toString() ?? '');
      }
      final ice = RTCIceCandidate(cand, mid, idx);
      if (_remoteDescriptionSet) {
        await _pc!.addCandidate(ice);
      } else {
        _pendingRemoteIce.add(ice);
      }
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
    _finish(notify: true, kind: CallEndKind.localHangup);
  }

  void setMicEnabled(bool on) {
    final s = _localStream;
    if (s == null) return;
    for (final t in s.getAudioTracks()) {
      t.enabled = on;
    }
  }

  void _finish({bool notify = true, CallEndKind kind = CallEndKind.disposeSilent}) {
    if (_ended) return;
    _ended = true;
    try {
      _socketSub?.cancel();
    } catch (_) {}
    _socketSub = null;

    try {
      _stopLocalCameraTracks();
    } catch (_) {}

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _localStream = null;

    try {
      _pc?.close();
    } catch (_) {}
    _pc = null;

    try {
      _remoteCombinedStream = null;
      remoteRenderer.srcObject = null;
    } catch (_) {}

    try {
      localRenderer.srcObject = null;
    } catch (_) {}

    if (notify) {
      final text = buildCallChatMessage(
        isCaller: isCaller,
        hadP2PConnected: _hadP2PConnected,
        connectedAt: _connectedAt,
        callerAckCompleted: _callerAck.isCompleted,
        calleeAnswerSent: _answerSent,
        kind: kind,
      );
      final post = onChatMessage;
      if (text != null && post != null) {
        post(text);
      }
      onEnded();
    }
  }

  Future<void> dispose() async {
    if (!_ended) {
      _sendHangup();
    }
    _finish(notify: false, kind: CallEndKind.disposeSilent);
    try {
      await remoteRenderer.dispose();
    } catch (_) {}
    try {
      await localRenderer.dispose();
    } catch (_) {}
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }
}
