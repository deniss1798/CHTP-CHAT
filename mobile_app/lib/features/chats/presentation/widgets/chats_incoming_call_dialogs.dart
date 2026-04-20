import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_surface.dart';
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
        builder: (dialogContext) {
          VoiceCallRing.registerIncomingDismiss(callId, () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          });

          return _IncomingCallDialogCard(
            badge: 'INCOMING CALL',
            title: title,
            subtitle: '$title Р·РІРѕРЅРёС‚ РІР°Рј',
            icon: AppIcons.call,
            acceptLabel: 'РџСЂРёРЅСЏС‚СЊ',
            declineLabel: 'РћС‚РєР»РѕРЅРёС‚СЊ',
            onDecline: () async {
              VoiceCallRing.end(callId);
              Navigator.of(dialogContext).pop();

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
            onAccept: () {
              VoiceCallRing.end(callId);
              Navigator.of(dialogContext).pop();
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
        builder: (dialogContext) => _IncomingCallDialogCard(
          badge: 'GROUP CALL',
          title: title,
          subtitle: 'Р’Р°СЃ Р·РѕРІСѓС‚ РІ Р·РІРѕРЅРѕРє В«$titleВ»',
          icon: Icons.groups_rounded,
          acceptLabel: 'РџСЂРёСЃРѕРµРґРёРЅРёС‚СЊСЃСЏ',
          declineLabel: 'РћС‚РєР»РѕРЅРёС‚СЊ',
          onDecline: () {
            VoiceCallRing.end(callId);
            Navigator.of(dialogContext).pop();
          },
          onAccept: () {
            VoiceCallRing.end(callId);
            Navigator.of(dialogContext).pop();
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
        ),
      );
    } finally {
      await IncomingCallRingtone.instance.stop();
    }
  }
}

class _IncomingCallDialogCard extends StatelessWidget {
  const _IncomingCallDialogCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.acceptLabel,
    required this.declineLabel,
    required this.onDecline,
    required this.onAccept,
  });

  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final String acceptLabel;
  final String declineLabel;
  final FutureOr<void> Function() onDecline;
  final FutureOr<void> Function() onAccept;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AppSurface(
        tone: AppSurfaceTone.elevated,
        radius: AppRadius.xxl,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPillBadge(
              label: badge,
              icon: icon,
              accent: true,
            ),
            const SizedBox(height: 18),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: AppGradients.accentPanel,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentBorder),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: AppColors.textOnAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onDecline();
                    },
                    icon: const Icon(AppIcons.callEnd),
                    label: Text(declineLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      onAccept();
                    },
                    icon: const Icon(AppIcons.call),
                    label: Text(acceptLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
