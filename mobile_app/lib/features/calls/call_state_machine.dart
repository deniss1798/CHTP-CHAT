enum CallStatus {
  created,
  ringing,
  accepted,
  declined,
  cancelled,
  missed,
  ended,
  failed,
  expired,
}

const Set<CallStatus> kTerminalCallStatuses = {
  CallStatus.declined,
  CallStatus.cancelled,
  CallStatus.missed,
  CallStatus.ended,
  CallStatus.failed,
  CallStatus.expired,
};

bool isTerminalCallStatus(CallStatus status) {
  return kTerminalCallStatuses.contains(status);
}

bool canTransitionCall(CallStatus from, CallStatus to) {
  if (from == to) return true;
  if (isTerminalCallStatus(from)) return false;

  switch (from) {
    case CallStatus.created:
      return to == CallStatus.ringing ||
          to == CallStatus.cancelled ||
          to == CallStatus.failed ||
          to == CallStatus.expired;
    case CallStatus.ringing:
      return to == CallStatus.accepted ||
          to == CallStatus.declined ||
          to == CallStatus.cancelled ||
          to == CallStatus.missed ||
          to == CallStatus.failed ||
          to == CallStatus.expired;
    case CallStatus.accepted:
      return to == CallStatus.ended || to == CallStatus.failed;
    case CallStatus.declined:
    case CallStatus.cancelled:
    case CallStatus.missed:
    case CallStatus.ended:
    case CallStatus.failed:
    case CallStatus.expired:
      return false;
  }
}

class CallStateMachine {
  CallStateMachine({CallStatus initial = CallStatus.created}) : status = initial;

  CallStatus status;

  bool transitionTo(CallStatus next) {
    if (!canTransitionCall(status, next)) return false;
    status = next;
    return true;
  }
}

CallStatus terminalStatusForCallEnd({
  required bool isCaller,
  required bool hadP2PConnected,
  required bool callerAckCompleted,
  required bool calleeAnswerSent,
  required CallEndReason reason,
}) {
  if (hadP2PConnected) return CallStatus.ended;

  switch (reason) {
    case CallEndReason.silentDispose:
      return CallStatus.cancelled;
    case CallEndReason.localHangup:
      if (isCaller && !callerAckCompleted) return CallStatus.cancelled;
      if (!isCaller && !calleeAnswerSent) return CallStatus.cancelled;
      return CallStatus.ended;
    case CallEndReason.remoteHangup:
      if (isCaller && !callerAckCompleted) return CallStatus.declined;
      if (!isCaller && !calleeAnswerSent) return CallStatus.cancelled;
      return CallStatus.ended;
    case CallEndReason.ackTimeout:
      return CallStatus.missed;
    case CallEndReason.error:
      return CallStatus.failed;
  }
}

enum CallEndReason {
  silentDispose,
  localHangup,
  remoteHangup,
  ackTimeout,
  error,
}
