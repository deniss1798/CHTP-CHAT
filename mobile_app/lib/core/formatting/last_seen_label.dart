/// Подпись «когда был в сети» для офлайн-пользователя.
///
/// - до 1 ч: «N мин назад» (меньше минуты — «только что»);
/// - от 1 ч до 3 ч включительно: «N ч назад» (целые часы вниз);
/// - более 3 ч, не старше суток: время «был в HH:mm»;
/// - более суток: дата «был DD.MM.YYYY».
abstract final class LastSeenLabel {
  LastSeenLabel._();

  /// [lastSeen] — момент последней активности (как приходит с API, UTC или local).
  static String formatOffline(DateTime? lastSeen) {
    if (lastSeen == null) {
      return 'не в сети';
    }

    final seen = lastSeen.isUtc ? lastSeen.toLocal() : lastSeen;
    final now = DateTime.now();
    var diff = now.difference(seen);
    if (diff.isNegative) {
      diff = Duration.zero;
    }

    if (diff < const Duration(hours: 1)) {
      final m = diff.inMinutes;
      if (m < 1) {
        return 'только что';
      }
      return '$m мин назад';
    }

    if (diff <= const Duration(hours: 3)) {
      final h = diff.inHours;
      return '$h ч назад';
    }

    if (diff <= const Duration(hours: 24)) {
      final hh = seen.hour.toString().padLeft(2, '0');
      final mm = seen.minute.toString().padLeft(2, '0');
      return 'был в $hh:$mm';
    }

    final d = seen.day.toString().padLeft(2, '0');
    final mo = seen.month.toString().padLeft(2, '0');
    final y = seen.year;
    return 'был $d.$mo.$y';
  }
}
