import '../../../../core/network/url_helper.dart';

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asTrimmedString(Object? value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

class ChatMember {
  const ChatMember({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.role,
    this.lastSeenAtRaw,
  });

  final int id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? role;
  final String? lastSeenAtRaw;

  factory ChatMember.fromApi(Map<String, dynamic> raw) {
    final id = _asInt(raw['id']);
    if (id == null) {
      throw const FormatException('Chat member id is missing');
    }

    return ChatMember(
      id: id,
      username: _asTrimmedString(raw['username']) ?? 'Пользователь',
      email: _asTrimmedString(raw['email']),
      avatarUrl: UrlHelper.absoluteMediaUrl(
        raw['avatar_url'] ?? raw['avatarUrl'],
      ),
      role: _asTrimmedString(raw['role']),
      lastSeenAtRaw: _asTrimmedString(raw['last_seen_at'] ?? raw['lastSeenAt']),
    );
  }
}

class ChatDetail {
  const ChatDetail({
    required this.id,
    required this.type,
    required this.title,
    this.avatarUrl,
    this.createdBy,
    required this.members,
  });

  final int id;
  final String type;
  final String title;
  final String? avatarUrl;
  final int? createdBy;
  final List<ChatMember> members;

  factory ChatDetail.fromApi(Map<String, dynamic> raw) {
    final id = _asInt(raw['id']);
    if (id == null) {
      throw const FormatException('Chat detail id is missing');
    }

    final membersRaw = raw['members'];
    final members = <ChatMember>[];
    if (membersRaw is List) {
      for (final item in membersRaw) {
        if (item is Map<String, dynamic>) {
          members.add(ChatMember.fromApi(item));
        } else if (item is Map) {
          members.add(ChatMember.fromApi(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ChatDetail(
      id: id,
      type: _asTrimmedString(raw['type']) ?? 'private',
      title: _asTrimmedString(raw['title']) ?? 'Чат',
      avatarUrl: UrlHelper.absoluteMediaUrl(
        raw['avatar_url'] ?? raw['avatarUrl'],
      ),
      createdBy: _asInt(raw['created_by'] ?? raw['createdBy']),
      members: members,
    );
  }
}

bool _asBool(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  final s = value.toString().trim().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return false;
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.type,
    required this.title,
    this.avatarUrl,
    this.createdBy,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageAtRaw,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.lastMessageId,
    required this.myLastReadMessageId,
    required this.unreadCount,
    this.peerLastSeenAtRaw,
    this.isArchived = false,
    this.notificationsMuted = false,
  });

  final int id;
  final String type;
  final String title;
  final String? avatarUrl;
  final int? createdBy;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastMessageAtRaw;
  final int? lastMessageSenderId;
  final String? lastMessageSenderName;
  final int? lastMessageId;
  final int myLastReadMessageId;
  final int unreadCount;
  final String? peerLastSeenAtRaw;

  /// Персонификация участника ([PATCH /chats/:id/member-preferences]).
  final bool isArchived;
  final bool notificationsMuted;

  factory ChatSummary.fromApi(Map<String, dynamic> raw) {
    final id = _asInt(raw['id'] ?? raw['chat_id']);
    if (id == null) {
      throw const FormatException('Chat id is missing');
    }

    return ChatSummary(
      id: id,
      type: _asTrimmedString(raw['type']) ?? 'private',
      title: _asTrimmedString(
            raw['title'] ??
                raw['display_name'] ??
                raw['name'] ??
                raw['chat_name'] ??
                raw['username'] ??
                raw['other_user_name'] ??
                raw['other_username'],
          ) ??
          'Чат $id',
      avatarUrl: UrlHelper.absoluteMediaUrl(
        raw['avatar_url'] ?? raw['avatarUrl'],
      ),
      createdBy: _asInt(raw['created_by'] ?? raw['createdBy']),
      lastMessage: _asTrimmedString(
        raw['last_message'] ??
            raw['lastMessage'] ??
            raw['message'] ??
            raw['last_message_text'] ??
            raw['content'],
      ),
      lastMessageType: _asTrimmedString(
        raw['last_message_type'] ?? raw['lastMessageType'],
      ),
      lastMessageAtRaw: _asTrimmedString(
        raw['last_message_at'] ?? raw['lastMessageAt'],
      ),
      lastMessageSenderId: _asInt(
        raw['last_message_sender_id'] ?? raw['lastMessageSenderId'],
      ),
      lastMessageSenderName: _asTrimmedString(
        raw['last_message_sender_name'] ?? raw['lastMessageSenderName'],
      ),
      lastMessageId: _asInt(raw['last_message_id'] ?? raw['lastMessageId']),
      myLastReadMessageId: _asInt(
            raw['my_last_read_message_id'] ?? raw['myLastReadMessageId'],
          ) ??
          0,
      unreadCount: _asInt(raw['unread_count'] ?? raw['unreadCount']) ?? 0,
      peerLastSeenAtRaw: _asTrimmedString(
        raw['peer_last_seen_at'] ?? raw['peerLastSeenAt'],
      ),
      isArchived:
          _asBool(raw['is_archived'] ?? raw['isArchived']),
      notificationsMuted:
          _asBool(raw['notifications_muted'] ?? raw['notificationsMuted']),
    );
  }

  ChatSummary copyWith({
    String? title,
    String? avatarUrl,
    String? lastMessage,
    String? lastMessageType,
    String? lastMessageAtRaw,
    int? lastMessageSenderId,
    String? lastMessageSenderName,
    int? lastMessageId,
    int? myLastReadMessageId,
    int? unreadCount,
    String? peerLastSeenAtRaw,
    bool? isArchived,
    bool? notificationsMuted,
  }) {
    return ChatSummary(
      id: id,
      type: type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageAtRaw: lastMessageAtRaw ?? this.lastMessageAtRaw,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName:
          lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      myLastReadMessageId: myLastReadMessageId ?? this.myLastReadMessageId,
      unreadCount: unreadCount ?? this.unreadCount,
      peerLastSeenAtRaw: peerLastSeenAtRaw ?? this.peerLastSeenAtRaw,
      isArchived: isArchived ?? this.isArchived,
      notificationsMuted: notificationsMuted ?? this.notificationsMuted,
    );
  }
}

class ChatListPageResult {
  const ChatListPageResult({
    required this.chats,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ChatSummary> chats;
  final bool hasMore;
  final String? nextCursor;
}
