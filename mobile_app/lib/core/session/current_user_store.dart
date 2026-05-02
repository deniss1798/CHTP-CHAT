import 'package:flutter/foundation.dart';

class CurrentUserStore {
  static Map<String, dynamic>? _user;

  static final ValueNotifier<int> _userVersion = ValueNotifier<int>(0);

  /// Bumps on [setUser] / [clear] so profile UI (nav rail) can rebuild.
  static ValueListenable<int> get userVersion => _userVersion;

  static Map<String, dynamic>? get user => _user;

  static int? get userId {
    final value = _user?['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static void setUser(Map<String, dynamic> user) {
    _user = user;
    _userVersion.value = _userVersion.value + 1;
  }

  static void clear() {
    _user = null;
    _userVersion.value = _userVersion.value + 1;
  }

  static bool get hasUser => _user != null;
}