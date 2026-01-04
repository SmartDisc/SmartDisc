// lib/services/api_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../env.dart';
import '../models/wurf.dart';

class ApiService {
  final http.Client _client = http.Client();

  Uri _u(String path, [Map<String, dynamic>? q]) => Uri.parse(
    '$apiBaseUrl$path',
  ).replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  // ---- READ ----
  Future<List<Wurf>> getWuerfe({int limit = 20, String? scheibeId}) async {
    final q = <String, dynamic>{'limit': limit};
    if (scheibeId != null) q['scheibe_id'] = scheibeId; // <-- add filter
    try {
      final res = await _client.get(_u('/wurfe', q));
      if (res.statusCode != 200) {
        // fallback to dummy data
        return await _generateDummyWuerfe(limit, scheibeId);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['items'] as List).cast<Map<String, dynamic>>();
      final list = items.map(Wurf.fromJson).toList();
      if (list.isEmpty) return await _generateDummyWuerfe(limit, scheibeId);
      return list;
    } catch (e) {
      // network or parsing error — return dummy data so UI can show samples
      return await _generateDummyWuerfe(limit, scheibeId);
    }
  }

  Future<List<Wurf>> _generateDummyWuerfe(
    int limit,
    String? scheibeId, [
    List<String>? availableDiscIds,
  ]) async {
    final rnd = Random();
    final now = DateTime.now().toUtc();
    final cnt = limit.clamp(1, 20);

    // Try to get available disc IDs from backend if not provided
    List<String>? discIds = availableDiscIds;
    if (discIds == null) {
      try {
        final discs = await getDiscs();
        discIds = discs.map((d) => (d['id'] as String?) ?? '').where((id) => id.isNotEmpty).toList();
      } catch (_) {
        // If fetching fails, discIds will remain null and we'll use fallback
      }
    }

    // prepare a small pool of discs; prefer backend disc IDs if available
    final discPool = scheibeId != null
        ? [scheibeId]
        : (discIds != null && discIds.isNotEmpty)
            ? discIds
            : List.generate(
                10,
                (j) => 'DISC-${(j + 1).toString().padLeft(2, '0')}',
              );

    return List.generate(cnt, (i) {
      // spread timestamps: most recent items within minutes, others spread across days
      final ageSeconds = (i * (20 + rnd.nextInt(300))) + (rnd.nextInt(60));
      final extraDays = rnd.nextInt(8); // 0..7 days ago
      final ms = now.subtract(Duration(seconds: ageSeconds, days: extraDays));

      final id =
          'T${now.millisecondsSinceEpoch}_${i}_${rnd.nextInt(9000) + 1000}';
      final disc = discPool[i % discPool.length];

      return Wurf(
        id: id,
        scheibeId: disc,
        entfernung: double.parse(
          ((rnd.nextDouble() * 50) + 8).toStringAsFixed(1),
        ),
        geschwindigkeit: double.parse(
          (rnd.nextDouble() * 14 + 3).toStringAsFixed(2),
        ),
        rotation: double.parse(
          (rnd.nextDouble() * 12 + 0.3).toStringAsFixed(2),
        ),
        hoehe: double.parse((rnd.nextDouble() * 7 + 0.2).toStringAsFixed(2)),
        erstelltAm: ms.toIso8601String(),
      );
    });
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
    final res = await _client.get(_u('/scheiben'));
    if (res.statusCode != 200) {
      throw Exception('getDiscs failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    return items;
  }

  // ---- CREATE ----
  /// Create a new throw with aggregated sensor data
  /// Returns the created throw ID
  Future<String> createThrow({
    required String scheibeId,
    String? playerId,
    required double rotation,
    required double height,
    required double accelerationMax,
  }) async {
    final payload = {
      'scheibe_id': scheibeId,
      if (playerId != null) 'player_id': playerId,
      'rotation': rotation,
      'hoehe': height,
      'acceleration_max': accelerationMax,
    };
    final res = await _client.post(
      _u('/wurfe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) {
      final errorBody = jsonDecode(res.body) as Map<String, dynamic>;
      final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
      throw Exception('createThrow failed: ${res.statusCode} - $errorMsg');
    }
    final response = jsonDecode(res.body) as Map<String, dynamic>;
    return response['id'] as String;
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
      headers: {'Content-Type': 'application/json'},
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
    final res = await _client.delete(_u('/scheiben/$id'));
    if (res.statusCode != 200) {
      final errorBody = jsonDecode(res.body) as Map<String, dynamic>;
      final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
      throw Exception('deleteDisc failed: ${res.statusCode} - $errorMsg');
    }
  }
}
