/// Один активный медиазвонок на процесс: личный (1:1) или групповой.
class CallCoordinator {
  CallCoordinator._();

  static bool _voice = false;
  static bool _group = false;

  static bool get hasAny => _voice || _group;

  static bool tryEnterVoice() {
    if (hasAny) return false;
    _voice = true;
    return true;
  }

  static void exitVoice() {
    _voice = false;
  }

  static bool tryEnterGroup() {
    if (hasAny) return false;
    _group = true;
    return true;
  }

  static void exitGroup() {
    _group = false;
  }
}
