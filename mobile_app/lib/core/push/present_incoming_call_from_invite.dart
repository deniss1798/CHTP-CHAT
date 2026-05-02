import '../../app/app.dart';
import '../../features/chats/presentation/widgets/chats_incoming_call_dialogs.dart';
import '../../features/calls/voice_call_ring.dart';
import '../session/current_user_store.dart';

int? incomingCallInviteChatId(Map<String, dynamic> invite) {
  final raw = invite['chat_id'];
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '');
}

/// Открыть UI входящего по payload из FCM или из pending cold start (вне WebSocket inbox).
Future<void> presentIncomingCallFromInviteMap(Map<String, dynamic> invite) async {
  if (invite.isEmpty) return;
  final navigatorContext = appNavigatorKey.currentContext;
  if (navigatorContext == null) return;

  final callId = invite['call_id']?.toString() ?? '';
  if (callId.isEmpty) return;
  if (!VoiceCallRing.tryStart(callId)) return;

  final rawUser = CurrentUserStore.user;
  final myId = int.tryParse(rawUser?['id']?.toString() ?? '');
  if (myId == null) {
    VoiceCallRing.end(callId);
    return;
  }

  final chatId = incomingCallInviteChatId(invite);
  if (chatId == null) {
    VoiceCallRing.end(callId);
    return;
  }

  final type = invite['type']?.toString() ?? '';
  try {
    if (type == 'group_call_invite') {
      final starter = int.tryParse(invite['started_by']?.toString() ?? '');
      final startedBy =
          starter ?? int.tryParse(invite['user_id']?.toString() ?? '') ?? 0;
      await ChatsIncomingCallDialogs.showGroupCallInvite(
        context: navigatorContext,
        chatId: chatId,
        currentUserId: myId,
        startedByUserId: startedBy,
        title: 'Групповой чат',
        withVideo: invite['video'] == true,
        invite: invite,
      );
      return;
    }

    if (type == 'call_e2e_init') {
      final callerId = int.tryParse(invite['user_id']?.toString() ?? '');
      if (callerId == null) {
        VoiceCallRing.end(callId);
        return;
      }
      await ChatsIncomingCallDialogs.showPrivateCallInvite(
        context: navigatorContext,
        chatId: chatId,
        callerId: callerId,
        currentUserId: myId,
        title: 'Чат',
        invite: invite,
      );
      return;
    }
  } catch (_) {}
}
