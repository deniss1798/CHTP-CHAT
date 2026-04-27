import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chats/presentation/controllers/chat_socket_event_controller.dart';
import 'package:mobile_app/features/chats/presentation/controllers/message_list_controller.dart';

void main() {
  group('ChatSocketEventController dedupe', () {
    test('deduplicates events by event_id', () {
      final controller = ChatSocketEventController();
      final event = {
        'event_id': 'evt-1',
        'type': 'new_message',
        'message': {'id': 10},
      };

      expect(controller.shouldProcess(event), isTrue);
      expect(controller.shouldProcess(event), isFalse);
    });

    test('builds fallback key from message payload', () {
      final controller = ChatSocketEventController();
      final event = {
        'type': 'new_message',
        'message': {'id': '11'},
      };

      expect(controller.eventKey(event), 'new_message:message:11');
    });
  });

  group('MessageListController optimistic messages', () {
    test('marks temp message failed and sending again', () {
      final controller = MessageListController();
      final messages = <Map<String, dynamic>>[
        {
          'client_temp_id': 'tmp-1',
          'text': 'hello',
          'delivery_status': 'sending',
        },
      ];

      expect(
        controller.markClientTempFailed(
          messages,
          clientTempId: 'tmp-1',
          error: 'network',
        ),
        isTrue,
      );
      expect(messages.single['delivery_status'], 'failed');
      expect(messages.single['error'], 'network');

      expect(
        controller.markClientTempSending(messages, clientTempId: 'tmp-1'),
        isTrue,
      );
      expect(messages.single['delivery_status'], 'sending');
      expect(messages.single.containsKey('error'), isFalse);
    });

    test('replaces temp message with server message', () {
      final controller = MessageListController();
      final messages = <Map<String, dynamic>>[
        {'client_temp_id': 'tmp-1', 'text': 'hello'},
      ];

      expect(
        controller.replaceByClientTempId(
          messages,
          clientTempId: 'tmp-1',
          replacement: {'id': 42, 'text': 'hello'},
        ),
        isTrue,
      );
      expect(messages.single['id'], 42);
      expect(messages.single.containsKey('client_temp_id'), isFalse);
    });
  });
}
