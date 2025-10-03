import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _emailKey = 'auth_email';

  Future<bool> isLoggedIn() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
  }

  Future<void> login({required String email, required String password}) async {
    // Placeholder login: accept any non-empty email/password.
    // Replace with real API call and token management.
    if (email.isEmpty || password.isEmpty) {
      throw Exception('E-Mail und Passwort dürfen nicht leer sein.');
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, 'dev-token');
    await prefs.setString(_emailKey, email);
  }

  Future<String?> currentUserEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }
}


