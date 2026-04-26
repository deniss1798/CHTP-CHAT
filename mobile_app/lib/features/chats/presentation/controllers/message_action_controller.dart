import '../chat_detail_message_maps.dart';

class MessageActionController {
  bool isMine(Map<String, dynamic> message, int? currentUserId) {
    if (currentUserId == null) return false;
    final senderId = ChatDetailMessageMaps.intFromDynamic(message['sender_id']);
    return senderId == currentUserId;
  }

  bool canEdit(Map<String, dynamic> message, int? currentUserId) {
    if (!isMine(message, currentUserId)) return false;
    if (message['is_deleted'] == true) return false;
    return (message['message_type'] ?? 'text').toString() == 'text';
  }

  bool canDelete(Map<String, dynamic> message, int? currentUserId) {
    if (!isMine(message, currentUserId)) return false;
    return message['is_deleted'] != true;
  }
}
