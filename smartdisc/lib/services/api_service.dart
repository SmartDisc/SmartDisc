// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';
import '../models/wurf.dart';
import '../models/messung.dart';

class ApiService {
  final http.Client _client = http.Client();

  Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('$apiBase$path').replace(
        queryParameters: q?.map((k, v) => MapEntry(k, '$v')),
      );

  // ---- READ ----
  Future<List<Wurf>> getWuerfe({int limit = 20, String? scheibeId}) async {
    final q = <String, dynamic>{'limit': limit};
    if (scheibeId != null) q['scheibe_id'] = scheibeId;   // <-- add filter
    final res = await _client.get(_u('/api/wurfe', q));
    if (res.statusCode != 200) {
      throw Exception('getWuerfe failed: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Wurf.fromJson).toList();
  }

  Future<List<Messung>> getMessungen({int limit = 50, String? wurfId}) async {
    final q = <String, dynamic>{'limit': limit};
    if (wurfId != null) q['wurf_id'] = wurfId;
    final res = await _client.get(_u('/api/messungen', q));
    if (res.statusCode != 200) {
      throw Exception('getMessungen failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Messung.fromJson).toList();
  }

  Future<Map<String, dynamic>> getSummary() async {
    final res = await _client.get(_u('/api/stats/summary'));
    if (res.statusCode != 200) {
      throw Exception('summary failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---- CREATE DUMMY (for testing now) ----
  Future<String> createDummyWurf() async {
    final payload = {
      'scheibe_id': 'scheibe1',
      'entfernung': 25.5,
      'geschwindigkeit': 12.3,
    };
    final res = await _client.post(
      _u('/api/wurfe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      throw Exception('createDummyWurf failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<String> createDummyMessung(String wurfId) async {
    final payload = {
      'wurf_id': wurfId,
      'zeitpunkt': DateTime.now().toUtc().toIso8601String(),
      'beschleunigung_x': 0.44,
      'beschleunigung_y': 0.12,
      'beschleunigung_z': 9.75,
      'temperatur': 22.9,
    };
    final res = await _client.post(
      _u('/api/messungen'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      throw Exception('createDummyMessung failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
  }

  
}



