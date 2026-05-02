import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chats/domain/chat_list_rules.dart';

void main() {
  group('previewForLastMessageType', () {
    test('returns media labels for known message types', () {
      expect(previewForLastMessageType('image'), 'Фото');
      expect(previewForLastMessageType('video_note'), 'Видеосообщение');
      expect(previewForLastMessageType('document'), 'Файл');
      expect(previewForLastMessageType('call_event'), 'Вызов');
      expect(previewForLastMessageType('deleted'), 'Сообщение удалено');
    });

    test('returns null for text and fallback for unknown types', () {
      expect(previewForLastMessageType('text'), isNull);
      expect(previewForLastMessageType('custom'), 'Медиа');
    });
  });

  group('resolveChatListSubtitle', () {
    test('prefers message text when it exists', () {
      final subtitle = resolveChatListSubtitle(
        chatType: 'group',
        lastMessage: 'Привет',
        lastMessageType: 'image',
      );

      expect(subtitle, 'Привет');
    });

    test('falls back to media label and then chat type label', () {
      expect(
        resolveChatListSubtitle(
          chatType: 'private',
          lastMessageType: 'image',
        ),
        'Фото',
      );
      expect(
        resolveChatListSubtitle(chatType: 'group'),
        'Групповой чат',
      );
    });
  });

  group('resolveUnreadCount', () {
    test('uses backend unread count when it is already present', () {
      final unread = resolveUnreadCount(
        serverUnreadCount: 4,
        currentUserId: 1,
        lastMessageId: 10,
        lastMessageSenderId: 2,
        myLastReadMessageId: 2,
      );

      expect(unread, 4);
    });

    test('derives unread flag from last message when backend count is zero', () {
      final unread = resolveUnreadCount(
        serverUnreadCount: 0,
        currentUserId: 1,
        lastMessageId: 10,
        lastMessageSenderId: 2,
        myLastReadMessageId: 8,
      );

      expect(unread, 1);
    });

    test('does not mark own latest message as unread', () {
      final unread = resolveUnreadCount(
        serverUnreadCount: 0,
        currentUserId: 1,
        lastMessageId: 10,
        lastMessageSenderId: 1,
        myLastReadMessageId: 0,
      );

      expect(unread, 0);
    });
  });

  group('resolveTitleInitials', () {
    test('builds initials from first two words', () {
      expect(resolveTitleInitials('Code Green'), 'CG');
    });

    test('falls back to a single-letter or default title', () {
      expect(resolveTitleInitials('Messenger'), 'M');
      expect(resolveTitleInitials('   '), 'Ч');
    });
  });
}
