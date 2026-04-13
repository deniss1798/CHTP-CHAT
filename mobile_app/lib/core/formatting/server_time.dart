/// Разбор дат с API: значения без часового пояса считаем UTC (типично для PostgreSQL `timestamp` в Docker UTC).
DateTime? parseServerUtcInstant(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var s = raw.trim();
  if (s.endsWith('Z')) {
    return DateTime.tryParse(s)?.toUtc();
  }
  if (RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.tryParse(s)?.toUtc();
  }
  if (s.length >= 10 && s[10] == ' ') {
    s = s.replaceFirst(' ', 'T');
  }
  if (s.length >= 19 && s[10] == 'T') {
    return DateTime.tryParse('${s}Z')?.toUtc();
  }
  return DateTime.tryParse(s)?.toUtc();
}

int? serverInstantMillis(String? raw) =>
    parseServerUtcInstant(raw)?.millisecondsSinceEpoch;
