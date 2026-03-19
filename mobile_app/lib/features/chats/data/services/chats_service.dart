import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import 'local_chat_state_service.dart';

class ChatsService {
  final Dio _dio = ApiClient.dio;
  final LocalChatStateService _localChatStateService = LocalChatStateService();

  Future<List<Map<String, dynamic>>> getChats({
    required int currentUserId,
  }) async {
    final token = await SecureStorageService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Токен не найден');
    }

    final options = Options(
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final response = await _dio.get(
      '/chats/',
      options: options,
    );

    final data = response.data;

    List<Map<String, dynamic>> chats;

    if (data is List) {
      chats = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      throw Exception('Неожиданный формат ответа /chats/');
    }

    final List<Map<String, dynamic>> enrichedChats = [];

    for (final chat in chats) {
      final enriched = Map<String, dynamic>.from(chat);

      final type = (chat['type'] ?? '').toString();
      final rawId = chat['id'] ?? chat['chat_id'];

      int? chatId;
      if (rawId is int) {
        chatId = rawId;
      } else {
        chatId = int.tryParse(rawId.toString());
      }

      if (chatId == null) {
        enrichedChats.add(enriched);
        continue;
      }

      if (type == 'private') {
        try {
          final detailResponse = await _dio.get(
            '/chats/$chatId',
            options: options,
          );

          final detailData = detailResponse.data;

          if (detailData is Map<String, dynamic>) {
            final otherUser = detailData['other_user'];

            if (otherUser is Map<String, dynamic>) {
              final username = (otherUser['username'] ?? '').toString().trim();
              if (username.isNotEmpty) {
                enriched['display_name'] = username;
              }
            } else if (otherUser is Map) {
              final map = Map<String, dynamic>.from(otherUser);
              final username = (map['username'] ?? '').toString().trim();
              if (username.isNotEmpty) {
                enriched['display_name'] = username;
              }
            }
          }
        } catch (_) {}
      }

      try {
        final messagesResponse = await _dio.get(
          '/messages/$chatId',
          options: options,
        );

        final messagesData = messagesResponse.data;

        if (messagesData is List) {
          final messages = messagesData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          if (messages.isNotEmpty) {
            messages.sort((a, b) {
              final aDate =
                  DateTime.tryParse(a['created_at']?.toString() ?? '');
              final bDate =
                  DateTime.tryParse(b['created_at']?.toString() ?? '');

              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return -1;
              if (bDate == null) return 1;

              return aDate.compareTo(bDate);
            });

            final lastMessage = messages.last;
            final lastMessageText =
                (lastMessage['text'] ?? '').toString().trim();

            enriched['last_message'] = lastMessageText;
            enriched['last_message_at'] = lastMessage['created_at'];
            enriched['last_message_id'] = lastMessage['id'];
            enriched['last_sender_id'] = lastMessage['sender_id'];

            final lastReadMessageId =
                await _localChatStateService.getLastReadMessageId(chatId);

            int unreadCount = 0;

            for (final message in messages) {
              final messageIdRaw = message['id'];
              final senderIdRaw = message['sender_id'];

              int? messageId;
              int? senderId;

              if (messageIdRaw is int) {
                messageId = messageIdRaw;
              } else {
                messageId = int.tryParse(messageIdRaw.toString());
              }

              if (senderIdRaw is int) {
                senderId = senderIdRaw;
              } else {
                senderId = int.tryParse(senderIdRaw.toString());
              }

              final isOtherUserMessage =
                  senderId != null && senderId != currentUserId;
              final isUnread = lastReadMessageId == null
                  ? isOtherUserMessage
                  : (messageId != null &&
                      messageId > lastReadMessageId &&
                      isOtherUserMessage);

              if (isUnread) {
                unreadCount++;
              }
            }

            enriched['unread_count'] = unreadCount;
          } else {
            enriched['last_message'] = '';
            enriched['last_message_at'] = chat['created_at'];
            enriched['last_message_id'] = null;
            enriched['last_sender_id'] = null;
            enriched['unread_count'] = 0;
          }
        }
      } catch (_) {
        enriched['last_message'] ??= '';
        enriched['last_message_at'] ??= chat['created_at'];
        enriched['unread_count'] ??= 0;
      }

      enrichedChats.add(enriched);
    }

    enrichedChats.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['last_message_at']?.toString() ?? '') ??
              DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          DateTime.tryParse(b['last_message_at']?.toString() ?? '') ??
              DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return enrichedChats;
  }
}