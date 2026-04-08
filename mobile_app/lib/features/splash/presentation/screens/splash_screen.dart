import 'package:flutter/material.dart';
import '../../../../app/app.dart';
import '../../../../app/desktop_chat_session.dart';
import '../../../../app/home_chats_route.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../../core/platform/desktop_layout.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final token = await SecureStorageService.getAccessToken();

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      final pendingChatId = consumePendingPushChatId();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => buildHomeChatsScreen()),
      );

      if (pendingChatId != null) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (isDesktopMessengerLayout) {
            desktopChatOpenRequest.value = DesktopChatOpenRequest(
              chatId: pendingChatId,
              title: 'Чат',
              chatType: 'private',
            );
            return;
          }

          final navigator = appNavigatorKey.currentState;
          if (navigator == null) return;

          navigator.push(
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                chatId: pendingChatId,
                title: 'Чат',
                chatType: 'private',
              ),
            ),
          );
        });
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: const SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ЧТП ЧАТ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 14),
                CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}