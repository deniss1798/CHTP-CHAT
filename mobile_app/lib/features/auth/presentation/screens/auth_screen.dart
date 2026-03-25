import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../chats/presentation/screens/chats_screen.dart';
import '../../data/services/auth_service.dart';
import 'email_code_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool isLoginMode = true;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void toggleMode(bool loginMode) {
    setState(() {
      isLoginMode = loginMode;
    });
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      if (isLoginMode) {
        await _authService.login(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatsScreen()),
        );
      } else {
        final email = emailController.text.trim();

        final code = await _authService.requestEmailCode(
          username: usernameController.text.trim(),
          email: email,
          password: passwordController.text.trim(),
        );

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailCodeScreen(
              email: email,
              debugCode: code,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      String message = 'Произошла ошибка. Попробуйте снова.';

      if (e is DioException) {
        final data = e.response?.data;

        if (data is Map<String, dynamic>) {
          message = data['detail']?.toString() ??
              data['message']?.toString() ??
              message;
        } else if (data is String && data.isNotEmpty) {
          message = data;
        } else if (e.message != null && e.message!.isNotEmpty) {
          message = e.message!;
        }
      } else {
        message = e.toString().replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceSoft,
          content: Text(message),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите имя пользователя';
    }
    if (value.trim().length < 3) {
      return 'Минимум 3 символа';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите email';
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Введите корректный email';
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Минимум 6 символов';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Подтвердите пароль';
    }
    if (value != passwordController.text) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 120,
                left: -80,
                child: _GlowCircle(
                  size: 220,
                  color: AppColors.accent.withAlpha(20),
                ),
              ),
              Positioned(
                bottom: 80,
                right: -60,
                child: _GlowCircle(
                  size: 240,
                  color: AppColors.accent.withAlpha(26),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 60,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      const Text(
                        'CHTP',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Добро пожаловать',
                        style: textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isLoginMode
                            ? 'Войдите, чтобы продолжить общение'
                            : 'Создайте аккаунт и подтвердите email',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withAlpha(235),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppColors.accentBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withAlpha(26),
                              blurRadius: 50,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 112,
                              height: 84,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withAlpha(72),
                                    blurRadius: 32,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'ЧТП ЧАТ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _AuthSegmentedSwitch(
                              isLoginMode: isLoginMode,
                              onChanged: toggleMode,
                            ),
                            const SizedBox(height: 24),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  if (!isLoginMode) ...[
                                    TextFormField(
                                      controller: usernameController,
                                      validator: validateUsername,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Имя пользователя',
                                        prefixIcon: Icon(
                                          Icons.person_outline,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  TextFormField(
                                    controller: emailController,
                                    validator: validateEmail,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Email',
                                      prefixIcon: Icon(
                                        Icons.alternate_email,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: passwordController,
                                    validator: validatePassword,
                                    obscureText: obscurePassword,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Пароль',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        color: AppColors.textMuted,
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            obscurePassword = !obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isLoginMode) ...[
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: confirmPasswordController,
                                      validator: validateConfirmPassword,
                                      obscureText: obscureConfirmPassword,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Подтвердите пароль',
                                        prefixIcon: const Icon(
                                          Icons.lock_reset_outlined,
                                          color: AppColors.textMuted,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              obscureConfirmPassword =
                                                  !obscureConfirmPassword;
                                            });
                                          },
                                          icon: Icon(
                                            obscureConfirmPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.black,
                                        disabledBackgroundColor:
                                            AppColors.accent.withAlpha(140),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                  Colors.black,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              isLoginMode
                                                  ? 'Войти'
                                                  : 'Продолжить',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthSegmentedSwitch extends StatelessWidget {
  final bool isLoginMode;
  final ValueChanged<bool> onChanged;

  const _AuthSegmentedSwitch({
    required this.isLoginMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.inputBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              title: 'Вход',
              selected: isLoginMode,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              title: 'Регистрация',
              selected: !isLoginMode,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(64),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
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