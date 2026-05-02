import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

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

String? _readFileBesideExecutable() {
  try {
    final dir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final f = File('$dir$sep' 'api_base_url.txt');
    if (!f.existsSync()) {
      return null;
    }
    for (final line in f.readAsStringSync().split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) {
        continue;
      }
      return t;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String get resolvedApiBaseUrl {
  const env = String.fromEnvironment('API_BASE_URL');
  if (env.trim().isNotEmpty) {
    return _normalizeBase(env);
  }
  final fromFile = _readFileBesideExecutable();
  if (fromFile != null && fromFile.isNotEmpty) {
    if (kDebugMode) {
      debugPrint('[API] base from api_base_url.txt');
    }
    return _normalizeBase(fromFile);
  }
  return _normalizeBase('http://127.0.0.1:8000/api');
}
