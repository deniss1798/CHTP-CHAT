import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifiers/chats_list_refresh_notifier.dart';
import 'core/notifiers/open_chat_state_notifier.dart';
import 'core/push/local_notifications_service.dart';
import 'core/push/notification_preferences.dart';
import 'core/push/open_chat_from_push.dart';
import 'firebase_options.dart';

bool get _firebasePushSupported {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationPreferences.load();
  print('Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (LocalNotificationsService.supported) {
    await LocalNotificationsService.instance.init();
  }

  if (_firebasePushSupported) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initPush();
  }

  runApp(const MessengerApp());

  if (_firebasePushSupported) {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      setPendingPush(_pendingPushFromMessageData(initialMessage.data));
    }
  }
}

Future<void> _initPush() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  await messaging.getToken();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    requestChatsListRefresh();
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!await NotificationPreferences.areEnabled()) {
        return;
      }
      final data = message.data;
      final chatId = _extractChatId(data);
      if (chatId != null) {
        if (isChatOpenNow(chatId)) {
          return;
        }
        final n = message.notification;
        final titleRaw = (n?.title ?? '').trim();
        final bodyRaw = (n?.body ?? '').trim();
        final title = titleRaw.isNotEmpty
            ? n!.title!
            : (data['sender_name']?.toString() ?? 'Чат');
        final body =
            bodyRaw.isNotEmpty ? n!.body! : 'Новое сообщение';
        final av = _extractChatAvatarUrl(data);
        unawaited(
          LocalNotificationsService.instance.showChatMessage(
            notificationId: chatId,
            title: title,
            body: body,
            avatarUrl: av,
            chatId: chatId,
            avatarUrlForOpen: av,
          ),
        );
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final payload = _pendingPushFromMessageData(message.data);
    if (payload != null) {
      openChatFromPushPayload(payload);
    }
  });
}

int? _extractChatId(Map<String, dynamic> data) {
  final rawChatId = data['chat_id'];
  if (rawChatId == null) return null;
  return int.tryParse(rawChatId.toString());
}

String? _extractChatAvatarUrl(Map<String, dynamic> data) {
  final raw = data['chat_avatar_url'];
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

PendingPushPayload? _pendingPushFromMessageData(Map<String, dynamic> data) {
  final chatId = _extractChatId(data);
  if (chatId == null) return null;
  return PendingPushPayload(
    chatId: chatId,
    avatarUrl: _extractChatAvatarUrl(data),
  );
}
