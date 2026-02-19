import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';
import 'auth_service.dart';

class AssignmentService {
  final http.Client _client = http.Client();
  final AuthService _authService = AuthService();

  Uri _u(String path) => Uri.parse('$apiBaseUrl$path');

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getAuthToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Get all players (trainer only)
  Future<List<Map<String, dynamic>>> getPlayers() async {
    final headers = await _getAuthHeaders();
    final res = await _client.get(_u('/assignments/players'), headers: headers);
    if (res.statusCode != 200) {
      throw Exception('getPlayers failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['players'] as List).cast<Map<String, dynamic>>();
  }

  /// Get assigned discs for a player
  Future<List<Map<String, dynamic>>> getPlayerAssignments(String playerId) async {
    final headers = await _getAuthHeaders();
    final res = await _client.get(
      _u('/assignments/player/$playerId'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('getPlayerAssignments failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['assignments'] as List).cast<Map<String, dynamic>>();
  }

  /// Assign disc to player (trainer only)
  Future<void> assignDisc({
    required String discId,
    required String playerId,
  }) async {
    final headers = await _getAuthHeaders();
    final res = await _client.post(
      _u('/assignments'),
      headers: headers,
      body: jsonEncode({
        'disc_id': discId,
        'player_id': playerId,
      }),
    );
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      throw Exception(error?['message'] ?? 'Assignment failed: ${res.statusCode}');
    }
  }

  /// Remove disc assignment (trainer only)
  Future<void> removeAssignment(int assignmentId) async {
    final headers = await _getAuthHeaders();
    final res = await _client.delete(
      _u('/assignments/$assignmentId'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      throw Exception(error?['message'] ?? 'Remove assignment failed: ${res.statusCode}');
    }
  }

  /// Get my assigned discs (player only)
  Future<List<Map<String, dynamic>>> getMyDiscs() async {
    final headers = await _getAuthHeaders();
    final res = await _client.get(_u('/assignments/my-discs'), headers: headers);
    if (res.statusCode != 200) {
      throw Exception('getMyDiscs failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['discs'] as List).cast<Map<String, dynamic>>();
  }
}
