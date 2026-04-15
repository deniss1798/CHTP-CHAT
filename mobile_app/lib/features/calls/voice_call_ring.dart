import 'package:flutter/foundation.dart';

/// Дедупликация входящего звонка при одновременной доставке в чат и в inbox.
/// [registerIncomingDismiss] — закрыть диалог «Входящий звонок», если пришёл [call_e2e_hangup].
class VoiceCallRing {
  static final Set<String> _ids = <String>{};
  static final Map<String, VoidCallback> _dismissIncoming =
      <String, VoidCallback>{};

  static bool tryStart(String callId) {
    if (callId.isEmpty) return false;
    if (_ids.contains(callId)) return false;
    _ids.add(callId);
    return true;
  }

  /// Вызывать из `AlertDialog` builder: при отмене звонка собеседником закрыть диалог.
  static void registerIncomingDismiss(String callId, VoidCallback onDismiss) {
    if (callId.isEmpty) return;
    _dismissIncoming[callId] = onDismiss;
  }

  static void unregisterIncomingDismiss(String callId) {
    _dismissIncoming.remove(callId);
  }

  /// Сигнал `call_e2e_hangup` по сокету — закрыть модалку ожидания, снять блокировку tryStart.
  static void dismissIncomingDialog(String callId) {
    if (callId.isEmpty) return;
    final cb = _dismissIncoming.remove(callId);
    _ids.remove(callId);
    try {
      cb?.call();
    } catch (_) {}
  }

  static void end(String callId) {
    _ids.remove(callId);
    _dismissIncoming.remove(callId);
  }
}
