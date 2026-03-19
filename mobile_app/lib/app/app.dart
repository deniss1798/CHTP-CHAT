import 'package:flutter/material.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import 'theme/app_theme.dart';

class MessengerApp extends StatelessWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ЧТП ЧАТ',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}