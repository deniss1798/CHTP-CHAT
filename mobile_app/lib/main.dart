import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/chats/presentation/screens/chat_detail_screen.dart';
import 'firebase_options.dart';

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

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await _initPush();

  runApp(const MessengerApp());

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    final chatId = _extractChatId(initialMessage.data);
    if (chatId != null) {
      setPendingPushChatId(chatId);
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

  final token = await messaging.getToken();
  print('FCM token: $token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message title: ${message.notification?.title}');
    print('Foreground message body: ${message.notification?.body}');
    print('Foreground message data: ${message.data}');
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