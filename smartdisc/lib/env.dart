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
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE', defaultValue: '');
  if (fromEnv.trim().isNotEmpty) return _normalizeBaseUrl(fromEnv);

  // Sensible defaults for local development.
  if (isAndroid) return 'http://10.0.2.2:8000/api';
  return 'http://localhost:8000/api';
}
