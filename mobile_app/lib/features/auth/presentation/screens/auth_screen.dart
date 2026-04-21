import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../../../app/home_chats_route.dart';
import '../../../../app/widgets/desktop_constrained_content.dart';
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
          MaterialPageRoute(builder: (_) => buildHomeChatsScreen()),
        );
      } else {
        final email = emailController.text.trim();

        await _authService.requestEmailCode(
          username: usernameController.text.trim(),
          email: email,
          password: passwordController.text.trim(),
        );

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailCodeScreen(
              email: email,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      String message = 'Произошла ошибка. Попробуйте снова.';

      if (e is DioException) {
        final data = e.response?.data;
        String? fromBody;
        if (data is Map<String, dynamic>) {
          fromBody = data['detail']?.toString() ?? data['message']?.toString();
        } else if (data is String && data.isNotEmpty) {
          fromBody = data;
        }

        if (fromBody != null && fromBody.isNotEmpty) {
          message = fromBody;
        } else if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          message = 'Нет соединения с сервером. Проверьте сеть.';
        } else if (e.response?.statusCode == 401) {
          message = 'Неверный email или пароль.';
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
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= AppBreakpoints.wideLayoutMinWidth;

    return Scaffold(
      body: AppScreenBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.lg,
            ),
            child: DesktopConstrainedContent(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - 60,
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Добро пожаловать',
                        style: wide
                            ? textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              )
                            : textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isLoginMode
                            ? 'Войдите, чтобы продолжить'
                            : 'Укажите данные — отправим код на почту',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      AppSurface(
                        tone: AppSurfaceTone.elevated,
                        radius: AppRadius.xxl,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          children: [
                            Container(
                              width: 108,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: AppGradients.accentPanel,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                boxShadow: AppShadows.primaryButton,
                              ),
                              alignment: Alignment.center,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'ЧТП ЧАТ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textOnAccent,
                                      letterSpacing: 0.3,
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
                                          AppIcons.person,
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
                                      hintText: 'Электронная почта',
                                      prefixIcon: Icon(
                                        AppIcons.email,
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
                                        AppIcons.lock,
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
                                              ? AppIcons.visibilityOff
                                              : AppIcons.visibilityOn,
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
                                          AppIcons.lockReset,
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
                                                ? AppIcons.visibilityOff
                                                : AppIcons.visibilityOn,
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
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
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
    return AppSurface(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(4),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.accentPanel : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? AppColors.accent.withAlpha(90)
                : Colors.transparent,
          ),
          boxShadow: selected ? AppShadows.lift : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
