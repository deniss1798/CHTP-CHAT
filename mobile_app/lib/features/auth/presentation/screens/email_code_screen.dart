import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/home_chats_route.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/desktop_constrained_content.dart';
import '../../data/services/auth_service.dart';

class EmailCodeScreen extends StatefulWidget {
  final String email;
  final String? debugCode;

  const EmailCodeScreen({
    super.key,
    required this.email,
    this.debugCode,
  });

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugCode != null && widget.debugCode!.isNotEmpty) {
      _codeController.text = widget.debugCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? validateCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите код';
    }
    if (value.trim().length != 6) {
      return 'Код должен содержать 6 символов';
    }
    return null;
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      await _authService.verifyEmailCode(
        email: widget.email,
        code: _codeController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => buildHomeChatsScreen()),
        (route) => false,
      );
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
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'CHTP',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Подтверждение почты',
                        style: wide
                            ? textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              )
                            : textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.debugCode == null
                            ? 'Введите код, отправленный на ${widget.email}'
                            : 'Тестовый режим: используйте код ниже',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withAlpha(248),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(100),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Container(
                                width: 112,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withAlpha(48),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
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
                              const SizedBox(height: 24),
                              if (widget.debugCode != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSecondary,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Код подтверждения',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.debugCode!,
                                        style: const TextStyle(
                                          color: AppColors.accentBright,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _codeController,
                                validator: validateCode,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Код подтверждения',
                                  prefixIcon: Icon(
                                    Icons.verified_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
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
                                      borderRadius: BorderRadius.circular(18),
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
                                      : const Text(
                                          'Подтвердить',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Назад',
                                  style: TextStyle(
                                    color: AppColors.accentBright,
                                    fontWeight: FontWeight.w700,
                                  ),
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
            ),
          ),
        ),
    );
  }
}