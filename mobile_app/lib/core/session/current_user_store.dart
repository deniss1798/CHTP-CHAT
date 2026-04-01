class CurrentUserStore {
  static Map<String, dynamic>? _user;

  static Map<String, dynamic>? get user => _user;

  static int? get userId {
    final value = _user?['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static void setUser(Map<String, dynamic> user) {
    _user = user;
  }

  static void clear() {
    _user = null;
  }

  static bool get hasUser => _user != null;
}