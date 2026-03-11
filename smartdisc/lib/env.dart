import 'platform/platform_info.dart';

String _normalizeBaseUrl(String raw) {
  var s = raw.trim();
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  return s;
}

/// Base URL for the backend API.
///
/// Override per build/run using:
/// `--dart-define=API_BASE=http://<host>:8000/api`
///
/// Notes:
/// - On Android emulator, `localhost` points to the emulator itself. Use `10.0.2.2`
///   to reach the host machine.
/// - On a physical device, you must use a reachable LAN/VPN IP/hostname.
const String kDefaultApiBaseUrl = 'https://app.smartdisc.at/api';

String? _cachedApiBaseUrl;

String get apiBaseUrl {
  if (_cachedApiBaseUrl != null) return _cachedApiBaseUrl!;
  
  const fromEnv = String.fromEnvironment('API_BASE', defaultValue: '');

  if (fromEnv.trim().isNotEmpty) {
    final url = _normalizeBaseUrl(fromEnv);
    print('[ENV] Using API_BASE from environment: $url');
    _cachedApiBaseUrl = url;
    return url;
  }

  // Fallback to production backend URL.
  print('[ENV] Using default API URL: $kDefaultApiBaseUrl (isAndroid: $isAndroid)');
  _cachedApiBaseUrl = kDefaultApiBaseUrl;
  return kDefaultApiBaseUrl;
}
