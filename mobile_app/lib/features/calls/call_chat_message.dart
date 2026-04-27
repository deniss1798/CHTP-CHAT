import 'call_state_machine.dart';

String _formatDuration(Duration d) {
  final total = d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// One line for the chat after a call, or null if nothing should be posted.
String? buildCallChatMessage({
  required bool isCaller,
  required bool hadP2PConnected,
  required DateTime? connectedAt,
  required bool callerAckCompleted,
  required bool calleeAnswerSent,
  required CallEndReason reason,
}) {
  final status = terminalStatusForCallEnd(
    isCaller: isCaller,
    hadP2PConnected: hadP2PConnected,
    callerAckCompleted: callerAckCompleted,
    calleeAnswerSent: calleeAnswerSent,
    reason: reason,
  );

  switch (status) {
    case CallStatus.ended:
      if (connectedAt != null) {
        final d = DateTime.now().difference(connectedAt);
        return '📞 Вызов завершён · ${_formatDuration(d)}';
      }
      return '📞 Вызов завершён';
    case CallStatus.missed:
      return isCaller ? '📞 Пропущенный вызов' : null;
    case CallStatus.cancelled:
      return isCaller ? '📞 Вызов отменён' : null;
    case CallStatus.declined:
      return isCaller ? '📞 Звонок отклонён' : null;
    case CallStatus.failed:
      return null;
    case CallStatus.created:
    case CallStatus.ringing:
    case CallStatus.accepted:
    case CallStatus.expired:
      return null;
  }
}
