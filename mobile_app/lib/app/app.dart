import 'package:flutter/material.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

int? _pendingPushChatId;

void setPendingPushChatId(int chatId) {
  _pendingPushChatId = chatId;
}

int? consumePendingPushChatId() {
  final value = _pendingPushChatId;
  _pendingPushChatId = null;
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