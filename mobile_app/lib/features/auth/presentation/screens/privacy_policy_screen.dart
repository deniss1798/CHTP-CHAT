import 'package:flutter/material.dart';

import '../../../../app/widgets/app_screen_background.dart';

/// Заглушка: сюда позже вынесем полный текст политики конфиденциальности.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Политика конфиденциальности'),
      ),
      body: const AppScreenBackground(
        child: SizedBox.expand(),
      ),
    );
  }
}
