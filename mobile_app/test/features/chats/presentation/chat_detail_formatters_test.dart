import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chats/presentation/chat_detail_formatters.dart';

void main() {
  group('chatDetailFormatDocSize', () {
    test('formats bytes, KB and MB', () {
      expect(chatDetailFormatDocSize(42), '42 Б');
      expect(chatDetailFormatDocSize(1536), '1.5 КБ');
      expect(chatDetailFormatDocSize(2 * 1024 * 1024), '2.0 МБ');
    });
  });

  group('chatDetailReplyPreviewLabel', () {
    test('treats file alias as document', () {
      expect(
        chatDetailReplyPreviewLabel({
          'message_type': 'file',
          'text': 'report.pdf',
        }),
        '📎 report.pdf',
      );
    });
  });
}
