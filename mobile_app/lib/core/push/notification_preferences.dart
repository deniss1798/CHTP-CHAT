import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  NotificationPreferences._();

  static const _enabledKey = 'notifications_enabled';

  static final ValueNotifier<bool> enabledListenable = ValueNotifier<bool>(true);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabledListenable.value = prefs.getBool(_enabledKey) ?? true;
  }

  static Future<bool> areEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    enabledListenable.value = value;
  }
}
