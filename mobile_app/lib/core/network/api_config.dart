import 'api_config_io.dart' if (dart.library.html) 'api_config_web.dart' as impl;

/// `dart-define` → **Windows/macOS/Linux:** `api_base_url.txt` рядом с exe → иначе localhost:8000/api.
String get resolvedApiBaseUrl => impl.resolvedApiBaseUrl;
