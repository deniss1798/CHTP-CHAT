import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/calls/call_chat_message.dart';

void main() {
  group('buildCallChatMessage', () {
    test('returns duration when call connected', () {
      final text = buildCallChatMessage(
        isCaller: true,
        hadP2PConnected: true,
        connectedAt: DateTime.now().subtract(const Duration(seconds: 65)),
        callerAckCompleted: true,
        calleeAnswerSent: true,
        kind: CallEndKind.localHangup,
      );

      expect(text, startsWith('📞 Вызов завершён. Длительность: 01:'));
    });

    test('returns cancelled message before caller ack', () {
      final text = buildCallChatMessage(
        isCaller: true,
        hadP2PConnected: false,
        connectedAt: null,
        callerAckCompleted: false,
        calleeAnswerSent: false,
        kind: CallEndKind.localHangup,
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
        kind: CallEndKind.disposeSilent,
      );

      expect(text, isNull);
    });
  });
}
