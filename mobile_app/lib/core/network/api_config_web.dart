String _normalizeBase(String raw) {
  final t = raw.trim();
  if (t.isEmpty) {
    return 'http://127.0.0.1:8000/api';
  }
  if (t.endsWith('/')) {
    return t.substring(0, t.length - 1);
  }
  return t;
}

String get resolvedApiBaseUrl {
  const env = String.fromEnvironment('API_BASE_URL');
  if (env.trim().isNotEmpty) {
    return _normalizeBase(env);
  }
  return _normalizeBase('http://127.0.0.1:8000/api');
}
