import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import '../../../../app/app.dart';
import '../../../../app/home_chats_route.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../core/push/open_chat_from_push.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../calls/data/ice_config_service.dart';
import '../../../auth/presentation/screens/auth_screen.dart';

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
      // FCM getToken() / POST /devices может долго висеть на Android — не блокируем сплэш.
      unawaited(
        AuthService().registerPushTokenIfLoggedIn().catchError(
          (Object e, StackTrace st) =>
              debugPrint('registerPushTokenIfLoggedIn: $e\n$st'),
        ),
      );
      unawaited(
        IceConfigService.instance.prefetch().catchError(
          (Object e, StackTrace st) =>
              debugPrint('IceConfigService.prefetch: $e\n$st'),
        ),
      );

      final pendingPush = consumePendingPush();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => buildHomeChatsScreen()),
      );

      final push = pendingPush;
      if (push != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future<void>.delayed(
            const Duration(milliseconds: 120),
            () => openChatFromPushPayload(push),
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
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppSurface(
                tone: AppSurfaceTone.elevated,
                radius: AppRadius.xxl,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
                shadow: AppShadows.card,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppPillBadge(label: 'SECURE MESSAGING', accent: true),
                    SizedBox(height: 18),
                    Text(
                      'ЧТП ЧАТ',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Запускаем интерфейс и восстанавливаем сессию…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
