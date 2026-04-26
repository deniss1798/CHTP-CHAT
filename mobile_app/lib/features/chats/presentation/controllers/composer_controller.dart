import 'package:flutter/widgets.dart';

class ComposerController {
  String normalizedText(TextEditingController controller) => controller.text.trim();

  bool canSendText({
    required TextEditingController controller,
    required bool isSending,
  }) {
    return normalizedText(controller).isNotEmpty && !isSending;
  }
}
