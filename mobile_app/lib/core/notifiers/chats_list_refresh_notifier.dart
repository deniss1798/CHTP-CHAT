import 'package:flutter/foundation.dart';

/// Инкремент — тихое обновление списка чатов (FCM в foreground и т.д.).
final ValueNotifier<int> chatsListRefreshNotifier = ValueNotifier<int>(0);

void requestChatsListRefresh() {
  chatsListRefreshNotifier.value++;
}
