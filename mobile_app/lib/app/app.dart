import 'package:flutter/material.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Данные из FCM при cold start (открытие чата из уведомления).
class PendingPushPayload {
  const PendingPushPayload({
    required this.chatId,
    this.avatarUrl,
    this.incomingCallInvite,
  });

  final int chatId;
  final String? avatarUrl;
  /// То же событие, что приходит из inbox WS (cold start после FCM tap).
  final Map<String, dynamic>? incomingCallInvite;
}

PendingPushPayload? _pendingPush;

void setPendingPush(PendingPushPayload? payload) {
  _pendingPush = payload;
}

PendingPushPayload? consumePendingPush() {
  final value = _pendingPush;
  _pendingPush = null;
  return value;
}

class MessengerApp extends StatelessWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ЧТП ЧАТ',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}