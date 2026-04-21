import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';

/// Полноэкранный просмотр фото (как в Telegram: тёмный фон, жесты, только кнопка закрытия).
class ChatDetailFullscreenImageViewer extends StatelessWidget {
  const ChatDetailFullscreenImageViewer({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Не удалось загрузить фото',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(AppIcons.close, color: Colors.white),
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
