/// How the voice call ended (for optional chat line).
enum CallEndKind {
  disposeSilent,
  localHangup,
  remoteHangup,
  ackTimeout,
  error,
}

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
  required CallEndKind kind,
}) {
  if (hadP2PConnected && connectedAt != null) {
    final d = DateTime.now().difference(connectedAt);
    return '📞 Вызов завершён. Длительность: ${_formatDuration(d)}';
  }
  switch (kind) {
    case CallEndKind.disposeSilent:
    case CallEndKind.error:
      return null;
    case CallEndKind.ackTimeout:
      return isCaller ? '📞 Нет ответа' : null;
    case CallEndKind.remoteHangup:
      if (isCaller) {
        return '📞 Звонок отклонён';
      }
      return '📞 Вызов отменён';
    case CallEndKind.localHangup:
      if (isCaller && !callerAckCompleted) {
        return '📞 Вызов отменён';
      }
      if (!isCaller && !calleeAnswerSent) {
        return null;
      }
      return null;
  }
}
