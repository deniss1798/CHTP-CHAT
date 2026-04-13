import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/desktop_chat_session.dart';
import 'core/notifiers/chats_list_refresh_notifier.dart';
import 'core/platform/desktop_layout.dart';
import 'features/chats/presentation/screens/chat_detail_screen.dart';
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

  if (_firebasePushSupported) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initPush();
  }

  runApp(const MessengerApp());

  if (_firebasePushSupported) {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final chatId = _extractChatId(initialMessage.data);
      if (chatId != null) {
        setPendingPushChatId(chatId);
      }
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
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Opened from push: ${message.data}');
    final chatId = _extractChatId(message.data);
    if (chatId != null) {
      _openChat(chatId);
    }
  });
}

int? _extractChatId(Map<String, dynamic> data) {
  final rawChatId = data['chat_id'];
  if (rawChatId == null) return null;
  return int.tryParse(rawChatId.toString());
}

void _openChat(int chatId) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;

  if (isDesktopMessengerLayout) {
    desktopChatOpenRequest.value = DesktopChatOpenRequest(
      chatId: chatId,
      title: 'Чат',
      chatType: 'private',
    );
    return;
  }

  navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatDetailScreen(
        chatId: chatId,
        title: 'Чат',
        chatType: 'private',
      ),
    ),
  );
}