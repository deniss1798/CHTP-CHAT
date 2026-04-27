import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/calls/call_chat_message.dart';
import 'package:mobile_app/features/calls/call_state_machine.dart';

void main() {
  group('buildCallChatMessage', () {
    test('returns duration when call connected', () {
      final text = buildCallChatMessage(
        isCaller: true,
        hadP2PConnected: true,
        connectedAt: DateTime.now().subtract(const Duration(seconds: 65)),
        callerAckCompleted: true,
        calleeAnswerSent: true,
        reason: CallEndReason.localHangup,
      );

      expect(text, startsWith('📞 Вызов завершён · 01:'));
    });

    test('returns cancelled message before caller ack', () {
      final text = buildCallChatMessage(
        isCaller: true,
        hadP2PConnected: false,
        connectedAt: null,
        callerAckCompleted: false,
        calleeAnswerSent: false,
        reason: CallEndReason.localHangup,
      );

      expect(text, '📞 Вызов отменён');
    });

    test('does not post a message for silent dispose', () {
      final text = buildCallChatMessage(
        isCaller: false,
        hadP2PConnected: false,
        connectedAt: null,
        callerAckCompleted: false,
        calleeAnswerSent: false,
        reason: CallEndReason.silentDispose,
      );

      expect(text, isNull);
    });

    test('returns missed message for caller timeout', () {
      final text = buildCallChatMessage(
        isCaller: true,
        hadP2PConnected: false,
        connectedAt: null,
        callerAckCompleted: false,
        calleeAnswerSent: false,
        reason: CallEndReason.ackTimeout,
      );

      expect(text, '📞 Пропущенный вызов');
    });
  });

  group('CallStateMachine', () {
    test('allows expected lifecycle transitions', () {
      final machine = CallStateMachine();

      expect(machine.transitionTo(CallStatus.ringing), isTrue);
      expect(machine.transitionTo(CallStatus.accepted), isTrue);
      expect(machine.transitionTo(CallStatus.ended), isTrue);
    });

    test('rejects reopening terminal calls', () {
      final machine = CallStateMachine(initial: CallStatus.ringing);

      expect(machine.transitionTo(CallStatus.declined), isTrue);
      expect(machine.transitionTo(CallStatus.accepted), isFalse);
      expect(machine.status, CallStatus.declined);
    });

    test('maps end reasons to stable terminal statuses', () {
      expect(
        terminalStatusForCallEnd(
          isCaller: true,
          hadP2PConnected: false,
          callerAckCompleted: false,
          calleeAnswerSent: false,
          reason: CallEndReason.ackTimeout,
        ),
        CallStatus.missed,
      );
      expect(
        terminalStatusForCallEnd(
          isCaller: false,
          hadP2PConnected: true,
          callerAckCompleted: true,
          calleeAnswerSent: true,
          reason: CallEndReason.remoteHangup,
        ),
        CallStatus.ended,
      );
    });
  });
}
