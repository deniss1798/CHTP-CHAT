import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Loops incoming call sound while the incoming-call dialog is open (callee).
class IncomingCallRingtone {
  IncomingCallRingtone._();
  static final IncomingCallRingtone instance = IncomingCallRingtone._();

  AudioPlayer? _player;
  bool _started = false;

  Future<void> start() async {
    if (kIsWeb) return;
    if (_started) return;
    _started = true;
    try {
      final p = AudioPlayer();
      _player = p;
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource('sounds/incoming_call.mp3'));
    } catch (e) {
      debugPrint('IncomingCallRingtone: $e');
      _started = false;
      _player = null;
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    final p = _player;
    _player = null;
    if (p == null) return;
    try {
      await p.stop();
      await p.dispose();
    } catch (e) {
      debugPrint('IncomingCallRingtone stop: $e');
    }
  }
}
