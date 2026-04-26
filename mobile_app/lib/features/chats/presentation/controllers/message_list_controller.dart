import '../chat_detail_message_maps.dart';

class MessageListController {
  bool appendIfMissing(
    List<Map<String, dynamic>> messages,
    Map<String, dynamic> message,
  ) {
    final id = ChatDetailMessageMaps.intFromDynamic(message['id']);
    final exists = id != null &&
        messages.any((m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == id);
    if (exists) return false;
    messages.add(message);
    return true;
  }

  bool markDeleted(List<Map<String, dynamic>> messages, int messageId) {
    final idx = messages.indexWhere(
      (m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == messageId,
    );
    if (idx < 0) return false;

    final copy = Map<String, dynamic>.from(messages[idx]);
    copy['text'] = 'Сообщение удалено';
    copy['message_type'] = 'deleted';
    copy['media_key'] = null;
    copy['media_url'] = null;
    copy['media_mime_type'] = null;
    copy['media_size'] = null;
    copy['is_deleted'] = true;
    copy['reactions'] = const [];
    messages[idx] = copy;
    return true;
  }

  bool applyReactions(
    List<Map<String, dynamic>> messages, {
    required int messageId,
    required List<Map<String, dynamic>> reactions,
  }) {
    final idx = messages.indexWhere(
      (m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == messageId,
    );
    if (idx < 0) return false;

    final copy = Map<String, dynamic>.from(messages[idx]);
    copy['reactions'] = reactions;
    messages[idx] = copy;
    return true;
  }

  bool replaceUpdated(
    List<Map<String, dynamic>> messages,
    Map<String, dynamic> updated,
  ) {
    final updatedId = ChatDetailMessageMaps.intFromDynamic(updated['id']);
    if (updatedId == null) return false;
    final idx = messages.indexWhere(
      (m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == updatedId,
    );
    if (idx < 0) return false;

    final previous = messages[idx];
    var merged = updated;
    final nextReactions = merged['reactions'];
    if (nextReactions is! List || nextReactions.isEmpty) {
      final previousReactions = previous['reactions'];
      if (previousReactions is List && previousReactions.isNotEmpty) {
        merged = Map<String, dynamic>.from(merged);
        merged['reactions'] = previousReactions;
      }
    }
    messages[idx] = merged;
    return true;
  }
}
