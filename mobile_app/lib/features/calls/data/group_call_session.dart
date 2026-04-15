import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, VoidCallback, ValueNotifier, defaultTargetPlatform, kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../call_coordinator.dart';
import 'webrtc_ice_config.dart';

const _groupCallSignalTypes = {
  'group_call_invite',
  'group_call_join',
  'group_call_sdp',
  'group_call_ice',
  'group_call_leave',
  'group_call_end',
};

const _maxGroupPeers = 8;

class _MeshPeer {
  _MeshPeer(this.userId);

  final int userId;
  RTCPeerConnection? pc;
  bool remoteDescriptionSet = false;
  final List<RTCIceCandidate> pendingIce = [];
  RTCVideoRenderer? renderer;
  bool iStartedNegotiation = false;

  /// Один поток на участника: при отдельных onTrack не затираем аудио видео.
  MediaStream? remoteMediaStream;
}

/// Групповой звонок (mesh): отдельный P2P с каждым участником. Сигналинг — по тому же WebSocket (без E2E SDP).
class GroupCallSession {
  GroupCallSession({
    required this.callId,
    required this.chatId,
    required this.myUserId,
    required this.startedByUserId,
    required this.send,
    required this.socketStream,
    required this.onStatus,
    required this.onParticipantCount,
    required this.onEnded,
    required this.startWithVideo,
    this.isHost = false,
  });

  static GroupCallSession? _active;

  static bool tryAcquire(GroupCallSession s) {
    final cur = _active;
    if (cur != null && cur._ended) {
      releaseStatic();
    }
    if (_active != null || !CallCoordinator.tryEnterGroup()) return false;
    _active = s;
    return true;
  }

  static void releaseStatic() {
    if (_active != null) {
      CallCoordinator.exitGroup();
    }
    _active = null;
  }

  static void releaseIfCurrent(GroupCallSession s) {
    if (_active != s) return;
    releaseStatic();
  }

  final String callId;
  final int chatId;
  final int myUserId;
  final int startedByUserId;
  final void Function(Map<String, dynamic> payload) send;
  final Stream<Map<String, dynamic>> socketStream;
  final void Function(String status) onStatus;
  final void Function(int totalParticipants) onParticipantCount;
  final VoidCallback onEnded;
  final bool startWithVideo;
  final bool isHost;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final Map<int, _MeshPeer> _peers = {};
  final Set<int> _remoteUserIds = {};

  MediaStream? _localStream;
  MediaStreamTrack? _localVideoTrack;
  MediaStream? _cameraOnlyStream;

  StreamSubscription<Map<String, dynamic>>? _socketSub;
  Timer? _joinBurstTimer;

  bool _ended = false;
  bool _cameraOn = false;
  bool _speakerphoneSet = false;

  bool get cameraOn => _cameraOn;

  /// Увеличивайте в UI через [ValueListenableBuilder], чтобы обновить сетку превью.
  final ValueNotifier<int> meshVersion = ValueNotifier<int>(0);

  void _bumpUi() {
    meshVersion.value++;
  }

  Map<int, RTCVideoRenderer> get remoteVideoRenderers {
    final m = <int, RTCVideoRenderer>{};
    for (final e in _peers.entries) {
      final r = e.value.renderer;
      if (r != null) {
        m[e.key] = r;
      }
    }
    return m;
  }

  Future<void> run() async {
    if (kIsWeb) {
      onStatus('Звонки в браузере не поддерживаются');
      GroupCallSession.releaseIfCurrent(this);
      onEnded();
      return;
    }

    await localRenderer.initialize();

    try {
      await _openLocal();
    } catch (e) {
      onStatus('Нет доступа к микрофону');
      GroupCallSession.releaseIfCurrent(this);
      onEnded();
      return;
    }

    _cameraOn = startWithVideo;

    _socketSub = socketStream.listen(_onSocketMessage, onError: (_) {});

    if (isHost) {
      send({
        'type': 'group_call_invite',
        'call_id': callId,
        'started_by': myUserId,
        'video': startWithVideo,
      });
    }

    _sendJoin();
    _startJoinBurst();

    if (myUserId < startedByUserId) {
      unawaited(_ensureOfferTo(startedByUserId));
    }

    _emitParticipantCount();
    if (!_ended) {
      onStatus('В эфире');
    }
  }

  Future<void> _openLocal() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw Exception('mic');
    }
    final camOk = await Permission.camera.request();
    if (startWithVideo && !camOk.isGranted) {
      onStatus('Камера недоступна — только аудио');
    }

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
      },
      'video': camOk.isGranted
          ? {
              'facingMode': 'user',
              'width': 640,
              'height': 480,
              'frameRate': 24,
            }
          : false,
    });
    final ls = _localStream!;
    for (final vt in ls.getVideoTracks()) {
      vt.enabled = startWithVideo && camOk.isGranted;
    }
    _localVideoTrack =
        ls.getVideoTracks().isNotEmpty ? ls.getVideoTracks().first : null;
    _cameraOn = _localVideoTrack != null && _localVideoTrack!.enabled;
    localRenderer.srcObject = ls;
  }

  Map<String, dynamic> _iceConfig() {
    final config = <String, dynamic>{
      'iceServers': buildIceServerConfig(),
      'sdpSemantics': 'unified-plan',
    };
    const forceRelay =
        bool.fromEnvironment('WEBRTC_FORCE_RELAY', defaultValue: false);
    if (forceRelay) {
      config['iceTransportPolicy'] = 'relay';
    }
    return config;
  }

  Future<RTCVideoRenderer> _rendererFor(int userId) async {
    final existing = _peers[userId]?.renderer;
    if (existing != null) return existing;
    final r = RTCVideoRenderer();
    await r.initialize();
    _peers.putIfAbsent(userId, () => _MeshPeer(userId));
    _peers[userId]!.renderer = r;
    return r;
  }

  _MeshPeer _ensurePeerRecord(int userId) {
    return _peers.putIfAbsent(userId, () => _MeshPeer(userId));
  }

  Future<void> _addLocalToPc(RTCPeerConnection pc) async {
    final s = _localStream;
    if (s == null) return;
    for (final t in s.getTracks()) {
      await pc.addTrack(t, s);
    }
  }

  Future<void> _ensureOfferTo(int peerId) async {
    if (_ended || peerId == myUserId) return;
    if (_remoteUserIds.length >= _maxGroupPeers) {
      onStatus('Лимит участников');
      return;
    }

    final rec = _ensurePeerRecord(peerId);
    if (rec.iStartedNegotiation && rec.pc != null) {
      final st = rec.pc!.signalingState;
      if (st == RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
          st == RTCSignalingState.RTCSignalingStateStable) {
        return;
      }
    }

    try {
      final pc = await createPeerConnection(_iceConfig());
      rec.pc = pc;
      rec.iStartedNegotiation = true;
      rec.remoteDescriptionSet = false;
      await _rendererFor(peerId);

      pc.onIceCandidate = (RTCIceCandidate? c) {
        if (_ended || c == null) return;
        unawaited(_sendIceToPeer(peerId, c));
      };

      pc.onTrack = (RTCTrackEvent e) {
        unawaited(_onRemoteTrack(peerId, e));
      };
      _wireMeshPeerConnection(peerId, pc);

      await _addLocalToPc(pc);

      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await pc.setLocalDescription(offer);
      final ld = await pc.getLocalDescription();
      if (ld?.sdp == null || (ld!.sdp ?? '').isEmpty) return;
      _sendSdp(peerId, ld.sdp!, ld.type ?? 'offer');
      _bumpUi();
    } catch (e) {
      onStatus('Сеть: $e');
    }
  }

  Future<void> _onRemoteTrack(int userId, RTCTrackEvent e) async {
    final r = await _rendererFor(userId);
    final rec = _ensurePeerRecord(userId);

    if (e.streams.isNotEmpty) {
      final s = e.streams.first;
      for (final t in s.getTracks()) {
        if (t.kind == 'audio') {
          t.enabled = true;
        }
      }
      r.srcObject = s;
      rec.remoteMediaStream = s;
      _attachRemoteVideoListenersForMeshPeer(s);
    } else if (e.track.kind == 'video' || e.track.kind == 'audio') {
      e.track.enabled = true;
      try {
        MediaStream? ms = rec.remoteMediaStream ?? r.srcObject;
        if (ms == null) {
          ms = await createLocalMediaStream('remote-$userId');
          rec.remoteMediaStream = ms;
          r.srcObject = ms;
        }
        var already = false;
        for (final t in ms.getTracks()) {
          if (t.id == e.track.id) {
            already = true;
            break;
          }
        }
        if (!already) {
          await ms.addTrack(e.track);
        }
        _attachRemoteVideoListenersForMeshPeer(ms);
      } catch (_) {}
    }
    _bumpUi();
  }

  /// Включение камеры у участника не даёт новый onTrack — обновляем сетку.
  void _attachRemoteVideoListenersForMeshPeer(MediaStream s) {
    for (final t in s.getVideoTracks()) {
      t.onUnMute = () => _bumpUi();
      t.onMute = () => _bumpUi();
    }
  }

  void _sendSdp(int toUserId, String sdp, String sdpType) {
    send({
      'type': 'group_call_sdp',
      'call_id': callId,
      'to_user_id': toUserId,
      'sdp': sdp,
      'sdp_type': sdpType,
    });
  }

  Future<void> _sendIceToPeer(int toUserId, RTCIceCandidate c) async {
    send({
      'type': 'group_call_ice',
      'call_id': callId,
      'to_user_id': toUserId,
      'c': c.candidate,
      'm': c.sdpMid,
      'i': c.sdpMLineIndex,
    });
  }

  void _sendJoin() {
    send({
      'type': 'group_call_join',
      'call_id': callId,
    });
  }

  void _startJoinBurst() {
    _joinBurstTimer?.cancel();
    var ticks = 0;
    _joinBurstTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (_ended) {
        t.cancel();
        return;
      }
      _sendJoin();
      ticks++;
      if (ticks >= 8) {
        t.cancel();
      }
    });
  }

  void _onSocketMessage(Map<String, dynamic> msg) {
    if (_ended) return;
    final t = msg['type']?.toString();
    if (t == null || !_groupCallSignalTypes.contains(t)) return;

    final cid = msg['call_id']?.toString();
    if (cid == null || cid != callId) return;

    switch (t) {
      case 'group_call_invite':
        break;
      case 'group_call_join':
        _onRemoteJoin(msg);
        break;
      case 'group_call_sdp':
        unawaited(_onRemoteSdp(msg));
        break;
      case 'group_call_ice':
        unawaited(_onRemoteIce(msg));
        break;
      case 'group_call_leave':
        _onRemoteHangup(msg);
        break;
      case 'group_call_end':
        _onCallEndedByRemote(msg);
        break;
      default:
        break;
    }
  }

  void _onRemoteJoin(Map<String, dynamic> msg) {
    final uid = _int(msg['user_id']);
    if (uid == null || uid == myUserId) return;

    if (!_remoteUserIds.contains(uid)) {
      _remoteUserIds.add(uid);
    }
    _emitParticipantCount();

    if (myUserId < uid) {
      unawaited(_ensureOfferTo(uid));
    }

    _bumpUi();
  }

  bool _sdpIsOffer(String typ) {
    final t = typ.trim().toLowerCase();
    return t == 'offer';
  }

  Future<void> _onRemoteSdp(Map<String, dynamic> msg) async {
    final from = _int(msg['user_id']);
    final to = _int(msg['to_user_id']);
    if (from == null || to == null || to != myUserId || from == myUserId) {
      return;
    }

    final sdp = msg['sdp']?.toString();
    final typRaw = msg['sdp_type']?.toString();
    if (sdp == null || sdp.isEmpty || typRaw == null || typRaw.isEmpty) {
      return;
    }
    final typ = typRaw.trim();

    if (!_remoteUserIds.contains(from)) {
      _remoteUserIds.add(from);
      _emitParticipantCount();
    }

    final rec = _ensurePeerRecord(from);

    try {
      if (_sdpIsOffer(typ)) {
        await _applyRemoteOffer(from, rec, sdp, typ);
      } else {
        await _applyRemoteAnswer(from, rec, sdp, typ);
      }
    } catch (e) {
      onStatus('Ошибка SDP: $e');
    }
  }

  /// Второй answer после stable — игнорируем (дубликат по сети / повторная доставка).
  Future<void> _applyRemoteAnswer(
    int from,
    _MeshPeer rec,
    String sdp,
    String typ,
  ) async {
    final pc = rec.pc;
    if (pc == null) return;
    final st = pc.signalingState;
    if (st == RTCSignalingState.RTCSignalingStateStable) {
      return;
    }
    if (st != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      return;
    }
    await pc.setRemoteDescription(RTCSessionDescription(sdp, typ));
    rec.remoteDescriptionSet = true;
    rec.iStartedNegotiation = false;
    await _flushIce(rec);
    _bumpUi();
  }

  Future<void> _rollbackPeerPc(_MeshPeer rec) async {
    try {
      await rec.pc?.close();
    } catch (_) {}
    rec.pc = null;
    rec.remoteMediaStream = null;
    rec.iStartedNegotiation = false;
    rec.remoteDescriptionSet = false;
    rec.pendingIce.clear();
  }

  void _ensureSpeakerphoneOnce() {
    if (_speakerphoneSet || _ended) return;
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _speakerphoneSet = true;
    unawaited(() async {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
    }());
  }

  void _wireMeshPeerConnection(int peerId, RTCPeerConnection pc) {
    pc.onConnectionState = (RTCPeerConnectionState s) {
      if (_ended) return;
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _ensureSpeakerphoneOnce();
      }
    };
  }

  Future<void> _applyRemoteOffer(
    int from,
    _MeshPeer rec,
    String sdp,
    String typ,
  ) async {
    var pc = rec.pc;

    // Renegotiation: уже stable (например после включения камеры).
    if (pc != null &&
        pc.signalingState == RTCSignalingState.RTCSignalingStateStable) {
      await pc.setRemoteDescription(RTCSessionDescription(sdp, typ));
      rec.remoteDescriptionSet = true;
      await _flushIce(rec);
      final ans = await pc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await pc.setLocalDescription(ans);
      final ld = await pc.getLocalDescription();
      if (ld?.sdp == null) return;
      _sendSdp(from, ld!.sdp!, ld.type ?? 'answer');
      _bumpUi();
      return;
    }

    // Glare: оба отправили offer. Оставляем offer с меньшим user id.
    if (pc != null &&
        pc.signalingState ==
            RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      if (from > myUserId) {
        return;
      }
      await _rollbackPeerPc(rec);
      pc = null;
    }

    if (pc == null) {
      final newPc = await createPeerConnection(_iceConfig());
      rec.pc = newPc;
      rec.iStartedNegotiation = false;
      rec.remoteDescriptionSet = false;
      await _rendererFor(from);

      newPc.onIceCandidate = (RTCIceCandidate? c) {
        if (_ended || c == null) return;
        unawaited(_sendIceToPeer(from, c));
      };
      newPc.onTrack = (RTCTrackEvent e) {
        unawaited(_onRemoteTrack(from, e));
      };
      _wireMeshPeerConnection(from, newPc);

      await _addLocalToPc(newPc);
      await newPc.setRemoteDescription(RTCSessionDescription(sdp, typ));
      rec.remoteDescriptionSet = true;
      await _flushIce(rec);

      final ans = await newPc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await newPc.setLocalDescription(ans);
      final ld = await newPc.getLocalDescription();
      if (ld?.sdp == null) return;
      _sendSdp(from, ld!.sdp!, ld.type ?? 'answer');
      _bumpUi();
    }
  }

  Future<void> _flushIce(_MeshPeer rec) async {
    final pc = rec.pc;
    if (pc == null || !rec.remoteDescriptionSet) return;
    final batch = List<RTCIceCandidate>.from(rec.pendingIce);
    rec.pendingIce.clear();
    for (final c in batch) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
  }

  Future<void> _onRemoteIce(Map<String, dynamic> msg) async {
    final from = _int(msg['user_id']);
    final to = _int(msg['to_user_id']);
    if (from == null || to == null || to != myUserId) return;

    final cand = msg['c']?.toString();
    if (cand == null || cand.isEmpty) return;

    final mid = msg['m']?.toString();
    final idxRaw = msg['i'];
    int? idx;
    if (idxRaw is int) {
      idx = idxRaw;
    } else {
      idx = int.tryParse(idxRaw?.toString() ?? '');
    }

    final ice = RTCIceCandidate(cand, mid, idx);
    final rec = _peers[from];
    final pc = rec?.pc;
    if (pc == null) {
      _ensurePeerRecord(from).pendingIce.add(ice);
      return;
    }
    if (rec!.remoteDescriptionSet) {
      try {
        await pc.addCandidate(ice);
      } catch (_) {}
    } else {
      rec.pendingIce.add(ice);
    }
  }

  void _onRemoteHangup(Map<String, dynamic> msg) {
    final uid = _int(msg['user_id']);
    if (uid == null || uid == myUserId) return;
    unawaited(_removePeer(uid));
  }

  void _onCallEndedByRemote(Map<String, dynamic> msg) {
    if (_ended) return;
    onStatus('Звонок завершён');
    _finish(notify: true);
  }


  Future<void> _removePeer(int userId) async {
    final rec = _peers.remove(userId);
    _remoteUserIds.remove(userId);
    if (rec != null) {
      rec.remoteMediaStream = null;
    }
    try {
      await rec?.pc?.close();
    } catch (_) {}
    try {
      rec?.renderer?.srcObject = null;
      await rec?.renderer?.dispose();
    } catch (_) {}
    _emitParticipantCount();
    if (_remoteUserIds.isEmpty) {
      onStatus('Участники отключились');
    }
    _bumpUi();
  }

  void _emitParticipantCount() {
    onParticipantCount(_remoteUserIds.length + 1);
  }

  void setMicEnabled(bool on) {
    final s = _localStream;
    if (s == null) return;
    for (final t in s.getAudioTracks()) {
      t.enabled = on;
    }
  }

  Future<void> setCameraEnabled(bool on) async {
    if (_ended) return;
    if (on == _cameraOn) return;

    final local = _localStream;
    if (local == null) return;

    final pcList = _peers.values.map((e) => e.pc).whereType<RTCPeerConnection>().toList();

    final vts = List<MediaStreamTrack>.from(local.getVideoTracks());
    if (vts.isNotEmpty) {
      for (final t in vts) {
        t.enabled = on;
      }
      _cameraOn = on;
      _localVideoTrack = vts.first;
      localRenderer.srcObject = local;
      _bumpUi();
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
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
          'frameRate': 24,
        },
      });
      _cameraOnlyStream = camStream;
      final vt = camStream.getVideoTracks().isNotEmpty
          ? camStream.getVideoTracks().first
          : null;
      if (vt == null) return;
      _localVideoTrack = vt;
      await local.addTrack(vt);
      for (final pc in pcList) {
        await pc.addTrack(vt, local);
      }
      localRenderer.srcObject = local;
      _cameraOn = true;
      await _renegotiateAll();
    } catch (e) {
      onStatus('Камера: $e');
    }
  }

  Future<void> switchCamera() async {
    final t = _localVideoTrack;
    if (t == null) return;
    try {
      await Helper.switchCamera(t);
    } catch (_) {}
  }

  Future<void> _renegotiateAll() async {
    for (final e in _peers.entries) {
      final peerId = e.key;
      final rec = e.value;
      final pc = rec.pc;
      if (pc == null) continue;
      try {
        final offer = await pc.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        });
        await pc.setLocalDescription(offer);
        rec.iStartedNegotiation = true;
        final ld = await pc.getLocalDescription();
        if (ld?.sdp == null) continue;
        _sendSdp(peerId, ld!.sdp!, ld.type ?? 'offer');
      } catch (_) {}
    }
  }

  void leave() {
    if (_ended) return;
    send({
      'type': 'group_call_leave',
      'call_id': callId,
    });
    _finish(notify: true);
  }

  void _finish({bool notify = true}) {
    if (_ended) return;
    _ended = true;
    _joinBurstTimer?.cancel();
    _joinBurstTimer = null;
    try {
      _socketSub?.cancel();
    } catch (_) {}
    _socketSub = null;

    for (final p in _peers.values) {
      try {
        final ro = p.renderer?.srcObject;
        ro?.getTracks().forEach((t) => t.stop());
      } catch (_) {}
      try {
        p.pc?.close();
      } catch (_) {}
      try {
        p.renderer?.srcObject = null;
      } catch (_) {}
    }

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _localStream = null;
    try {
      _cameraOnlyStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _cameraOnlyStream = null;

    for (final p in _peers.values) {
      unawaited(p.renderer?.dispose() ?? Future<void>.value());
    }
    _peers.clear();
    _remoteUserIds.clear();

    try {
      localRenderer.srcObject = null;
    } catch (_) {}

    GroupCallSession.releaseIfCurrent(this);
    if (notify) {
      onEnded();
    }
  }

  Future<void> dispose() async {
    _finish(notify: false);
    try {
      meshVersion.dispose();
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
