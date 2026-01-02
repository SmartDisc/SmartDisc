import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../env.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _emailKey = 'auth_email';
  static const String _roleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  static const String _firstNameKey = 'first_name';
  static const String _lastNameKey = 'last_name';

  final http.Client _client = http.Client();

  Uri _u(String path) => Uri.parse('$apiBaseUrl$path');

  Future<bool> isLoggedIn() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    
    // Backend logout aufrufen
    if (token != null) {
      try {
        await _client.post(
          _u('/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (e) {
        // Ignore errors on logout
      }
    }
    
    // Local storage löschen
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_firstNameKey);
    await prefs.remove(_lastNameKey);
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final res = await _client.post(
        _u('/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200) {
        final error = body['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Login fehlgeschlagen');
      }

      final user = body['user'] as Map<String, dynamic>;
      final token = body['token'] as String;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_emailKey, user['email'] as String);
      await prefs.setString(_roleKey, user['role'] as String);
      await prefs.setString(_userIdKey, user['id'] as String);
      await prefs.setString(_firstNameKey, user['first_name'] as String);
      await prefs.setString(_lastNameKey, user['last_name'] as String);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Netzwerkfehler: ${e.toString()}');
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String passwordConfirm,
    required String role,
  }) async {
    try {
      final res = await _client.post(
        _u('/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'email': email.trim(),
          'password': password,
          'password_confirm': passwordConfirm,
          'role': role,
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 201) {
        final error = body['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Registrierung fehlgeschlagen');
      }

      final user = body['user'] as Map<String, dynamic>;
      final token = body['token'] as String;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_emailKey, user['email'] as String);
      await prefs.setString(_roleKey, user['role'] as String);
      await prefs.setString(_userIdKey, user['id'] as String);
      await prefs.setString(_firstNameKey, user['first_name'] as String);
      await prefs.setString(_lastNameKey, user['last_name'] as String);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Netzwerkfehler: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> me() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    
    if (token == null) return null;
    
    try {
      final res = await _client.get(
        _u('/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['user'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<String?> currentUserEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<String?> currentUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<String?> getAuthToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}


