/// Дедупликация входящего звонка при одновременной доставке в чат и в inbox.
class VoiceCallRing {
  static final Set<String> _ids = {};

  static bool tryStart(String callId) {
    if (callId.isEmpty) return false;
    if (_ids.contains(callId)) return false;
    _ids.add(callId);
    return true;
  }

  static void end(String callId) {
    _ids.remove(callId);
  }
}
