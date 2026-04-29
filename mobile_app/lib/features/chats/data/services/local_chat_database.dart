import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../core/formatting/server_time.dart';
import '../models/chat_models.dart';

class LocalChatDatabase {
  LocalChatDatabase._();

  static final LocalChatDatabase instance = LocalChatDatabase._();

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    final db = sqlite3.open(p.join(dir.path, 'chtp_chat_local.sqlite'));
    _configure(db);
    _db = db;
    return db;
  }

  void _configure(Database db) {
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA busy_timeout = 3000;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS local_chats (
        id INTEGER PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        last_message_at_ms INTEGER NOT NULL DEFAULT 0,
        title_search TEXT NOT NULL DEFAULT '',
        subtitle_search TEXT NOT NULL DEFAULT '',
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS local_messages (
        local_key TEXT PRIMARY KEY,
        chat_id INTEGER NOT NULL,
        server_id INTEGER,
        client_message_id TEXT,
        payload TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL DEFAULT 0,
        text_search TEXT NOT NULL DEFAULT '',
        message_type TEXT NOT NULL DEFAULT 'text',
        delivery_status TEXT,
        updated_at_ms INTEGER NOT NULL,
        FOREIGN KEY(chat_id) REFERENCES local_chats(id) ON DELETE CASCADE
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_messages_chat_created
      ON local_messages(chat_id, created_at_ms, local_key);
    ''');
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_local_messages_server_id
      ON local_messages(server_id)
      WHERE server_id IS NOT NULL;
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_messages_client_id
      ON local_messages(chat_id, client_message_id)
      WHERE client_message_id IS NOT NULL;
    ''');
  }

  Future<void> upsertChats(List<ChatSummary> chats) async {
    if (chats.isEmpty) return;
    final db = await _database;
    final statement = db.prepare('''
      INSERT INTO local_chats (
        id, payload, updated_at_ms, last_message_at_ms, title_search,
        subtitle_search, is_archived, is_pinned
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        payload = excluded.payload,
        updated_at_ms = excluded.updated_at_ms,
        last_message_at_ms = excluded.last_message_at_ms,
        title_search = excluded.title_search,
        subtitle_search = excluded.subtitle_search,
        is_archived = excluded.is_archived,
        is_pinned = excluded.is_pinned;
    ''');
    db.execute('BEGIN IMMEDIATE;');
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final chat in chats) {
        statement.execute([
          chat.id,
          jsonEncode(_chatToJson(chat)),
          now,
          serverInstantMillis(chat.lastMessageAtRaw) ?? 0,
          chat.title.toLowerCase(),
          (chat.lastMessage ?? '').toLowerCase(),
          chat.isArchived ? 1 : 0,
          chat.isPinned ? 1 : 0,
        ]);
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      statement.dispose();
    }
  }

  Future<List<ChatSummary>> getChats() async {
    final db = await _database;
    final rows = db.select('''
      SELECT payload FROM local_chats
      ORDER BY is_pinned DESC, last_message_at_ms DESC, updated_at_ms DESC;
    ''');
    final chats = <ChatSummary>[];
    for (final row in rows) {
      final raw = row['payload'];
      if (raw is! String || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          chats.add(ChatSummary.fromApi(decoded));
        } else if (decoded is Map) {
          chats.add(ChatSummary.fromApi(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {}
    }
    chats.sort(compareChatSummariesListOrder);
    return chats;
  }

  Future<void> upsertMessages({
    required int chatId,
    required List<Map<String, dynamic>> messages,
  }) async {
    if (messages.isEmpty) return;
    final db = await _database;
    await _ensureChatRow(db, chatId);
    final statement = db.prepare('''
      INSERT INTO local_messages (
        local_key, chat_id, server_id, client_message_id, payload,
        created_at_ms, text_search, message_type, delivery_status, updated_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(local_key) DO UPDATE SET
        chat_id = excluded.chat_id,
        server_id = excluded.server_id,
        client_message_id = excluded.client_message_id,
        payload = excluded.payload,
        created_at_ms = excluded.created_at_ms,
        text_search = excluded.text_search,
        message_type = excluded.message_type,
        delivery_status = excluded.delivery_status,
        updated_at_ms = excluded.updated_at_ms;
    ''');
    db.execute('BEGIN IMMEDIATE;');
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final message in messages) {
        final localKey = _messageLocalKey(chatId, message);
        final serverId = _asInt(message['id']);
        final clientMessageId = _trimmed(message['client_message_id']);
        if (serverId != null) {
          db.execute(
            'DELETE FROM local_messages WHERE server_id = ? AND local_key <> ?;',
            [serverId, localKey],
          );
        }
        if (serverId != null && clientMessageId != null) {
          db.execute(
            '''
            DELETE FROM local_messages
            WHERE chat_id = ? AND client_message_id = ? AND server_id IS NULL;
            ''',
            [chatId, clientMessageId],
          );
        }
        statement.execute([
          localKey,
          chatId,
          serverId,
          clientMessageId,
          jsonEncode(message),
          serverInstantMillis(message['created_at']?.toString()) ?? now,
          (message['text'] ?? '').toString().toLowerCase(),
          (message['message_type'] ?? 'text').toString(),
          _trimmed(message['delivery_status']),
          now,
        ]);
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      statement.dispose();
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(int chatId) async {
    final db = await _database;
    final rows = db.select(
      '''
      SELECT payload FROM local_messages
      WHERE chat_id = ?
      ORDER BY created_at_ms ASC, local_key ASC;
      ''',
      [chatId],
    );
    final messages = <Map<String, dynamic>>[];
    for (final row in rows) {
      final raw = row['payload'];
      if (raw is! String || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          messages.add(decoded);
        } else if (decoded is Map) {
          messages.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return messages;
  }

  Future<void> deleteMessageByServerId(int messageId) async {
    final db = await _database;
    db.execute('DELETE FROM local_messages WHERE server_id = ?;', [messageId]);
  }

  Future<void> _ensureChatRow(Database db, int chatId) async {
    db.execute(
      '''
      INSERT INTO local_chats (id, payload, updated_at_ms)
      VALUES (?, ?, ?)
      ON CONFLICT(id) DO NOTHING;
      ''',
      [
        chatId,
        jsonEncode({
          'id': chatId,
          'type': 'private',
          'title': 'Chat $chatId',
          'my_last_read_message_id': 0,
          'unread_count': 0,
        }),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  String _messageLocalKey(int chatId, Map<String, dynamic> message) {
    final id = _asInt(message['id']);
    if (id != null) return 'server:$id';

    final clientId = _trimmed(
      message['client_message_id'] ?? message['client_temp_id'],
    );
    if (clientId != null) return 'client:$chatId:$clientId';

    final created = message['created_at']?.toString() ?? '';
    final text = message['text']?.toString() ?? '';
    return 'local:$chatId:$created:${text.hashCode}';
  }

  Map<String, dynamic> _chatToJson(ChatSummary chat) {
    return {
      'id': chat.id,
      'type': chat.type,
      'title': chat.title,
      'avatar_url': chat.avatarUrl,
      'created_by': chat.createdBy,
      'last_message': chat.lastMessage,
      'last_message_type': chat.lastMessageType,
      'last_message_at': chat.lastMessageAtRaw,
      'last_message_sender_id': chat.lastMessageSenderId,
      'last_message_sender_name': chat.lastMessageSenderName,
      'last_message_id': chat.lastMessageId,
      'my_last_read_message_id': chat.myLastReadMessageId,
      'unread_count': chat.unreadCount,
      'peer_last_seen_at': chat.peerLastSeenAtRaw,
      'is_archived': chat.isArchived,
      'notifications_muted': chat.notificationsMuted,
      'is_pinned': chat.isPinned,
    };
  }

  int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String? _trimmed(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}
