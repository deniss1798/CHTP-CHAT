import '../../data/services/messages_service.dart';
import '../chat_detail_message_maps.dart';

class MessageSendController {
  MessageSendController({MessagesService? messagesService})
      : _messagesService = messagesService ?? MessagesService();

  final MessagesService _messagesService;

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return ChatDetailMessageMaps.normalizeMessageMap(raw);
  }

  Future<Map<String, dynamic>> sendText({
    required int chatId,
    required String text,
    int? replyToMessageId,
    String? clientMessageId,
    List<int>? mentionUserIds,
  }) async {
    return _normalize(
      await _messagesService.sendMessage(
        chatId: chatId,
        text: text,
        replyToMessageId: replyToMessageId,
        clientMessageId: clientMessageId,
        mentionUserIds: mentionUserIds,
      ),
    );
  }

  Future<Map<String, dynamic>> createPoll({
    required int chatId,
    required String question,
    required List<String> options,
    bool allowsMultiple = false,
    bool isAnonymous = false,
    String? clientMessageId,
  }) async {
    return _normalize(
      await _messagesService.createPoll(
        chatId: chatId,
        question: question,
        options: options,
        allowsMultiple: allowsMultiple,
        isAnonymous: isAnonymous,
        clientMessageId: clientMessageId,
      ),
    );
  }

  Future<Map<String, dynamic>> sendImage({
    required int chatId,
    required String imagePath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    return _normalize(
      await _messagesService.sendPhotoMessage(
        chatId: chatId,
        imagePath: imagePath,
        fileName: fileName,
        replyToMessageId: replyToMessageId,
      ),
    );
  }

  Future<Map<String, dynamic>> sendVideo({
    required int chatId,
    required String videoPath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    return _normalize(
      await _messagesService.sendVideoMessage(
        chatId: chatId,
        videoPath: videoPath,
        fileName: fileName,
        replyToMessageId: replyToMessageId,
      ),
    );
  }

  Future<Map<String, dynamic>> sendVideoNote({
    required int chatId,
    required String videoPath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    return _normalize(
      await _messagesService.sendVideoNoteMessage(
        chatId: chatId,
        videoPath: videoPath,
        fileName: fileName,
        replyToMessageId: replyToMessageId,
      ),
    );
  }

  Future<Map<String, dynamic>> sendDocument({
    required int chatId,
    required String filePath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    return _normalize(
      await _messagesService.sendDocumentMessage(
        chatId: chatId,
        filePath: filePath,
        fileName: fileName,
        replyToMessageId: replyToMessageId,
      ),
    );
  }

  Future<Map<String, dynamic>> sendVoice({
    required int chatId,
    required String filePath,
    required String fileName,
    int? replyToMessageId,
  }) async {
    return _normalize(
      await _messagesService.sendVoiceMessage(
        chatId: chatId,
        filePath: filePath,
        fileName: fileName,
        replyToMessageId: replyToMessageId,
      ),
    );
  }
}
