import '../../../../core/realtime/chat_ws_contract.dart';
import '../chat_detail_message_maps.dart';

class TypingSocketEvent {
  const TypingSocketEvent({
    required this.userId,
    required this.typing,
  });

  final int userId;
  final bool typing;
}

class ReadReceiptSocketEvent {
  const ReadReceiptSocketEvent({
    required this.userId,
    required this.lastReadMessageId,
  });

  final int userId;
  final int lastReadMessageId;
}

class ReactionUpdateSocketEvent {
  const ReactionUpdateSocketEvent({
    required this.messageId,
    required this.reactions,
  });

  final int messageId;
  final List<Map<String, dynamic>> reactions;
}

class ChatSocketEventController {
  final Set<String> _seenEventIds = <String>{};
  final List<String> _seenEventOrder = <String>[];
  static const int _maxSeenEvents = 400;

  bool shouldProcess(Map<String, dynamic> event) {
    final key = eventKey(event);
    if (key == null || key.isEmpty) return true;
    if (_seenEventIds.contains(key)) return false;
    _seenEventIds.add(key);
    _seenEventOrder.add(key);
    while (_seenEventOrder.length > _maxSeenEvents) {
      _seenEventIds.remove(_seenEventOrder.removeAt(0));
    }
    return true;
  }

  String? eventKey(Map<String, dynamic> event) {
    final eventId = event['event_id']?.toString().trim();
    if (eventId != null && eventId.isNotEmpty) return eventId;

    final type = event['type']?.toString().trim();
    final name = event['event']?.toString().trim();
    final message = event['message'];
    final messageId = message is Map
        ? ChatDetailMessageMaps.intFromDynamic(message['id'])
        : null;
    if (messageId != null && (type?.isNotEmpty == true || name?.isNotEmpty == true)) {
      return '${type ?? name}:message:$messageId';
    }
    final deletedId = ChatDetailMessageMaps.intFromDynamic(event['id']);
    if (deletedId != null && name == ChatWsContract.eventMessageDeleted) {
      return '$name:deleted:$deletedId';
    }
    final reactionId = ChatDetailMessageMaps.intFromDynamic(event['message_id']);
    if (reactionId != null &&
        name == ChatWsContract.eventMessageReactionsUpdated) {
      return '$name:reactions:$reactionId:${event['occurred_at'] ?? ''}';
    }
    return null;
  }

  bool isGroupCallInvite(Map<String, dynamic> event) {
    return event['type'] == 'group_call_invite';
  }

  bool isIncomingCallHangup(Map<String, dynamic> event) {
    return event['type'] == 'call_e2e_hangup';
  }

  bool isIncomingCallInit(Map<String, dynamic> event) {
    return event['type'] == 'call_e2e_init';
  }

  TypingSocketEvent? typingEvent(Map<String, dynamic> event) {
    if (event['type'] != ChatWsContract.payloadTypeTyping) return null;
    final userId = ChatDetailMessageMaps.intFromDynamic(event['user_id']);
    if (userId == null) return null;
    return TypingSocketEvent(
      userId: userId,
      typing: event['typing'] != false,
    );
  }

  ReadReceiptSocketEvent? readReceiptEvent(Map<String, dynamic> event) {
    if (event['type'] != ChatWsContract.payloadTypeReadReceipt) return null;
    final userId = ChatDetailMessageMaps.intFromDynamic(event['user_id']);
    final lastRead = ChatDetailMessageMaps.intFromDynamic(
      event['last_read_message_id'],
    );
    if (userId == null || lastRead == null) return null;
    return ReadReceiptSocketEvent(
      userId: userId,
      lastReadMessageId: lastRead,
    );
  }

  int? deletedMessageId(Map<String, dynamic> event) {
    if (event['event'] != ChatWsContract.eventMessageDeleted) return null;
    return ChatDetailMessageMaps.intFromDynamic(event['id']);
  }

  ReactionUpdateSocketEvent? reactionUpdateEvent(Map<String, dynamic> event) {
    if (event['event'] != ChatWsContract.eventMessageReactionsUpdated) {
      return null;
    }
    final messageId = ChatDetailMessageMaps.intFromDynamic(event['message_id']);
    if (messageId == null) return null;

    final reactions = <Map<String, dynamic>>[];
    final raw = event['reactions'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          reactions.add(item);
        } else if (item is Map) {
          reactions.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return ReactionUpdateSocketEvent(
      messageId: messageId,
      reactions: reactions,
    );
  }

  Map<String, dynamic>? updatedMessage(Map<String, dynamic> event) {
    if (event['event'] != ChatWsContract.eventMessageUpdated) return null;
    final raw = event['message'];
    if (raw is! Map) return null;
    return ChatDetailMessageMaps.normalizeMessageMap(
      Map<String, dynamic>.from(raw),
    );
  }

  Map<String, dynamic>? newMessage(Map<String, dynamic> event) {
    if (event['type'] != ChatWsContract.payloadTypeNewMessage &&
        !event.containsKey('message')) {
      return null;
    }
    final payload = ChatDetailMessageMaps.extractMessagePayload(event);
    if (payload == null) return null;
    return ChatDetailMessageMaps.normalizeMessageMap(payload);
  }
}
