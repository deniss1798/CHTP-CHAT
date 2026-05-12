import '../chat_detail_message_maps.dart';

class MessageListController {
  void _dedupeByServerId(List<Map<String, dynamic>> messages, int serverId) {
    var kept = false;
    for (var i = messages.length - 1; i >= 0; i--) {
      final mid = ChatDetailMessageMaps.intFromDynamic(messages[i]['id']);
      if (mid != serverId) continue;
      if (!kept) {
        kept = true;
        continue;
      }
      messages.removeAt(i);
    }
  }

  int? _indexByClientTempKey(
    List<Map<String, dynamic>> messages,
    String clientTempId,
  ) {
    final idx = messages.indexWhere(
      (m) =>
          m['client_temp_id'] == clientTempId ||
          m['client_message_id'] == clientTempId,
    );
    return idx >= 0 ? idx : null;
  }

  /// Входящее своё сообщение с сервера заменяет строку без [id] с тем же [client_message_id].
  bool replaceOptimisticMatchingClientMessageId(
    List<Map<String, dynamic>> messages,
    Map<String, dynamic> incoming,
  ) {
    final cmid = incoming['client_message_id']?.toString().trim();
    if (cmid == null || cmid.isEmpty) return false;
    final sid = ChatDetailMessageMaps.intFromDynamic(incoming['id']);
    if (sid == null) return false;

    var replacedIdx = -1;
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final mid = ChatDetailMessageMaps.intFromDynamic(m['id']);
      if (mid != null) continue;
      final mcmid =
          m['client_message_id']?.toString() ?? m['client_temp_id']?.toString();
      if (mcmid != cmid) continue;
      messages[i] = Map<String, dynamic>.from(incoming);
      replacedIdx = i;
      break;
    }
    if (replacedIdx < 0) return false;

    _dedupeByServerId(messages, sid);
    return true;
  }

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

  bool replaceByClientTempId(
    List<Map<String, dynamic>> messages, {
    required String clientTempId,
    required Map<String, dynamic> replacement,
  }) {
    final idx = _indexByClientTempKey(messages, clientTempId);
    if (idx == null) return false;
    final replacementId = ChatDetailMessageMaps.intFromDynamic(replacement['id']);
    if (replacementId != null) {
      final existingIdx = messages.indexWhere(
        (m) => ChatDetailMessageMaps.intFromDynamic(m['id']) == replacementId,
      );
      if (existingIdx >= 0 && existingIdx != idx) {
        messages.removeAt(idx);
        _dedupeByServerId(messages, replacementId);
        return true;
      }
    }
    messages[idx] = replacement;
    if (replacementId != null) {
      _dedupeByServerId(messages, replacementId);
    }
    return true;
  }

  bool markClientTempFailed(
    List<Map<String, dynamic>> messages, {
    required String clientTempId,
    required String error,
  }) {
    final idx = _indexByClientTempKey(messages, clientTempId);
    if (idx == null) return false;
    final copy = Map<String, dynamic>.from(messages[idx]);
    copy['delivery_status'] = 'failed';
    copy['error'] = error;
    messages[idx] = copy;
    return true;
  }

  bool markClientTempSending(
    List<Map<String, dynamic>> messages, {
    required String clientTempId,
  }) {
    final idx = _indexByClientTempKey(messages, clientTempId);
    if (idx == null) return false;
    final copy = Map<String, dynamic>.from(messages[idx]);
    copy['delivery_status'] = 'sending';
    copy.remove('error');
    messages[idx] = copy;
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
