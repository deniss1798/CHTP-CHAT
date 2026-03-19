import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../chats/presentation/screens/chats_screen.dart';

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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatsScreen()),
      );
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0B0D),
              Color(0xFF09090B),
              Color(0xFF140A02),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 140,
              left: -70,
              child: _GlowCircle(
                size: 200,
                color: AppColors.accent.withAlpha(22),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -50,
              child: _GlowCircle(
                size: 220,
                color: AppColors.accent.withAlpha(30),
              ),
            ),
            const SafeArea(
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
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size / 2,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}