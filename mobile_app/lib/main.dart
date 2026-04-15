import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifiers/chats_list_refresh_notifier.dart';
import 'core/push/local_notifications_service.dart';
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

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('Permission status: ${settings.authorizationStatus}');

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  final token = await messaging.getToken();
  print('FCM token: $token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message title: ${message.notification?.title}');
    print('Foreground message body: ${message.notification?.body}');
    print('Foreground message data: ${message.data}');
    requestChatsListRefresh();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final data = message.data;
      final chatId = _extractChatId(data);
      if (chatId != null) {
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
    print('Opened from push: ${message.data}');
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
