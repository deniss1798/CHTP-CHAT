import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../calls/incoming_call_ringtone.dart';
import '../../../calls/presentation/screens/group_call_screen.dart';
import '../../../calls/presentation/screens/voice_call_screen.dart';
import '../../../calls/voice_call_ring.dart';
import '../../data/services/chat_socket_service.dart';

class ChatsIncomingCallDialogs {
  const ChatsIncomingCallDialogs._();

  static Future<void> showPrivateCallInvite({
    required BuildContext context,
    required int chatId,
    required int callerId,
    required int currentUserId,
    required String title,
    required Map<String, dynamic> invite,
  }) async {
    final callId = invite['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;

    await IncomingCallRingtone.instance.start();
    if (!context.mounted) {
      await IncomingCallRingtone.instance.stop();
      return;
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          VoiceCallRing.registerIncomingDismiss(callId, () {
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Входящий звонок',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              '$title звонит вам',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  VoiceCallRing.end(callId);
                  Navigator.of(ctx).pop();

                  final socket = ChatSocketService();
                  try {
                    await socket.connect(
                      chatId: chatId,
                      baseHttpUrl: ApiClient.baseUrl,
                    );
                    socket.sendJson({
                      'type': 'call_e2e_hangup',
                      'call_id': callId,
                    });
                    await Future<void>.delayed(
                      const Duration(milliseconds: 400),
                    );
                  } catch (_) {
                    // Best-effort hangup notification.
                  }
                  await socket.disconnect();
                },
                child: const Text('Отклонить'),
              ),
              TextButton(
                onPressed: () {
                  VoiceCallRing.end(callId);
                  Navigator.of(ctx).pop();
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => VoiceCallScreen(
                          chatId: chatId,
                          peerTitle: title,
                          peerUserId: callerId,
                          myUserId: currentUserId,
                          incomingInit: invite,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Принять'),
              ),
            ],
          );
        },
      );
    } finally {
      VoiceCallRing.unregisterIncomingDismiss(callId);
      await IncomingCallRingtone.instance.stop();
    }
  }

  static Future<void> showGroupCallInvite({
    required BuildContext context,
    required int chatId,
    required int currentUserId,
    required int startedByUserId,
    required String title,
    required bool withVideo,
    required Map<String, dynamic> invite,
  }) async {
    final callId = invite['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;

    await IncomingCallRingtone.instance.start();
    if (!context.mounted) {
      await IncomingCallRingtone.instance.stop();
      return;
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Групповой звонок',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Вас зовут в звонок «$title»',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
              },
              child: const Text('Отклонить'),
            ),
            TextButton(
              onPressed: () {
                VoiceCallRing.end(callId);
                Navigator.of(ctx).pop();
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupCallScreen(
                        chatId: chatId,
                        chatTitle: title,
                        myUserId: currentUserId,
                        callId: callId,
                        startedByUserId: startedByUserId,
                        memberNames: const <int, String>{},
                        isHost: false,
                        startWithVideo: withVideo,
                        incomingInvite: invite,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Принять'),
            ),
          ],
        ),
      );
    } finally {
      await IncomingCallRingtone.instance.stop();
    }
  }
}
