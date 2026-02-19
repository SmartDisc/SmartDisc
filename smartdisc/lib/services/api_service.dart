// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';
import '../models/wurf.dart';
import 'auth_service.dart';

class ApiService {
  final http.Client _client = http.Client();
  final AuthService _authService = AuthService();

  // Helper: Get auth headers with token
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

  Uri _u(String path, [Map<String, dynamic>? q]) => Uri.parse(
    '$apiBaseUrl$path',
  ).replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  // ---- EXPORT ----
  Future<List<int>> exportThrows({
    String format = 'csv',
    bool exportAll = false,
    String? discId,
    double? minHeight,
    double? maxHeight,
    double? minAcceleration,
    double? maxAcceleration,
    double? minRotation,
    double? maxRotation,
  }) async {
    final headers = await _getAuthHeaders();
    final q = <String, dynamic>{'format': format};

    if (!exportAll) {
      if (discId != null && discId.isNotEmpty) q['discId'] = discId;
      if (minHeight != null) q['minHeight'] = minHeight;
      if (maxHeight != null) q['maxHeight'] = maxHeight;
      if (minAcceleration != null) q['minAcc'] = minAcceleration;
      if (maxAcceleration != null) q['maxAcc'] = maxAcceleration;
      if (minRotation != null) q['minRot'] = minRotation;
      if (maxRotation != null) q['maxRot'] = maxRotation;
    }

    final res = await _client.get(
      _u('/exports/throws', q),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('export failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  // ---- READ ----
  Future<List<Wurf>> getWuerfe({int limit = 20, String? scheibeId}) async {
    final headers = await _getAuthHeaders();
    final q = <String, dynamic>{'limit': limit};
    if (scheibeId != null) q['scheibe_id'] = scheibeId;
    final res = await _client.get(_u('/wurfe', q), headers: headers);
    if (res.statusCode != 200) {
      throw Exception('getWuerfe failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Wurf.fromJson).toList();
  }

  Future<Map<String, dynamic>> getSummary() async {
    final res = await _client.get(_u('/stats/summary'));
    if (res.statusCode != 200) {
      throw Exception('summary failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetch all active discs from the backend
  Future<List<Map<String, dynamic>>> getDiscs() async {
    final headers = await _getAuthHeaders();
    final res = await _client.get(_u('/scheiben'), headers: headers);
    if (res.statusCode != 200) {
      throw Exception('getDiscs failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    return items;
  }

  // ---- CREATE ----
  /// Create a new throw with aggregated sensor data
  /// Returns a map with 'id' and optionally 'is_new_record' and 'record_type'
  Future<Map<String, dynamic>> createThrow({
    required String scheibeId,
    String? playerId,
    required double rotation,
    required double height,
    required double accelerationMax,
  }) async {
    final headers = await _getAuthHeaders();
    final payload = {
      'scheibe_id': scheibeId,
      if (playerId != null) 'player_id': playerId,
      'rotation': rotation,
      'hoehe': height,
      'acceleration_max': accelerationMax,
    };
    final res = await _client.post(
      _u('/wurfe'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      final errorBody = jsonDecode(res.body) as Map<String, dynamic>;
      final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
      throw Exception('createThrow failed: ${res.statusCode} - $errorMsg');
    }
    final response = jsonDecode(res.body) as Map<String, dynamic>;
    return {
      'id': response['id'] as String,
      'is_new_record': response['is_new_record'] ?? false,
      'record_type': response['record_type'] as String?,
    };
  }

  /// Create a new disc in the backend
  /// Returns the created disc ID
  Future<String> createDisc({
    required String id,
    String? name,
    String? modell,
    String? seriennummer,
    String? firmwareVersion,
    String? kalibrierungsdatum,
  }) async {
    final headers = await _getAuthHeaders();
    final payload = {
      'id': id,
      if (name != null) 'name': name,
      if (modell != null) 'modell': modell,
      if (seriennummer != null) 'seriennummer': seriennummer,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
      if (kalibrierungsdatum != null) 'kalibrierungsdatum': kalibrierungsdatum,
    };
    final res = await _client.post(
      _u('/scheiben'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      final errorBody = jsonDecode(res.body) as Map<String, dynamic>;
      final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
      throw Exception('createDisc failed: ${res.statusCode} - $errorMsg');
    }
    final response = jsonDecode(res.body) as Map<String, dynamic>;
    return response['id'] as String;
  }

  /// Delete (deactivate) a disc in the backend
  Future<void> deleteDisc(String id) async {
    final headers = await _getAuthHeaders();
    final res = await _client.delete(_u('/scheiben/$id'), headers: headers);
    if (res.statusCode != 200) {
      final errorBody = jsonDecode(res.body) as Map<String, dynamic>;
      final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
      throw Exception('deleteDisc failed: ${res.statusCode} - $errorMsg');
    }
  }
}
