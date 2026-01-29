import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class DiscService {
  static const _kKey = 'smartdisc_discs_cache';
  static final DiscService _instance = DiscService._internal();
  factory DiscService.instance() => _instance;
  DiscService._internal();

  final ApiService _api = ApiService();
  final ValueNotifier<List<Map<String, dynamic>>> discs = ValueNotifier([]);
  bool _initialized = false;
  String? _currentPlayerId;

  Future<void> init({String? playerId}) async {
    // Wenn sich der playerId ändert, Cache leeren und neu initialisieren
    if (_initialized && playerId == _currentPlayerId) return;
    
    // Wenn wir von Trainer zu Player wechseln oder umgekehrt, Cache leeren
    if (_initialized && ((playerId != null && _currentPlayerId == null) || (playerId == null && _currentPlayerId != null))) {
      await clearCache();
      _initialized = false;
    }
    
    // Für Spieler: Cache IMMER zuerst leeren, um alte Daten zu vermeiden
    if (playerId != null) {
      discs.value = []; // Sofort leeren, bevor Backend-Call
      await clearCache(); // Auch persistenten Cache löschen
    }
    
    _currentPlayerId = playerId;
    await _loadFromBackend();
    _initialized = true;
  }

  /// Load discs from backend, with optional cache fallback
  Future<void> _loadFromBackend() async {
    try {
      final items = await _api.getDiscs(playerId: _currentPlayerId);
      
      // Debug logging
      if (kDebugMode) {
        debugPrint('DiscService._loadFromBackend: playerId=${_currentPlayerId}, loaded ${items.length} discs');
        if (items.isNotEmpty) {
          debugPrint('  Disc IDs: ${items.map((d) => d['id']).join(', ')}');
        }
      }
      
      // Für Spieler: Wenn keine Discs zurückgegeben werden, Cache leeren
      if (_currentPlayerId != null && items.isEmpty) {
        discs.value = [];
        await clearCache();
        return;
      }
      discs.value = items;
      await _saveCache();
    } catch (e) {
      // If backend fails or player has no assigned discs, clear cache for players
      if (_currentPlayerId != null) {
        debugPrint('Failed to load discs from backend for player or no discs assigned: $e');
        discs.value = [];
        await clearCache();
      } else {
        // For trainers, try to load from cache
        debugPrint('Failed to load discs from backend: $e');
        await _loadFromCache();
      }
    }
  }
  
  /// Clear cache - useful when switching users or after logout
  Future<void> clearCache() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
    discs.value = [];
  }

  /// Save current discs to local cache (for offline access)
  Future<void> _saveCache() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, jsonEncode(discs.value));
  }

  /// Load discs from local cache
  Future<void> _loadFromCache() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kKey);
    if (s != null) {
      try {
        final parsed = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
        discs.value = parsed;
      } catch (_) {
        discs.value = [];
      }
    }
  }

  /// Add a new disc via backend API
  Future<void> add(String id, {String? name}) async {
    try {
      await _api.createDisc(id: id, name: name ?? id);
      await _loadFromBackend();
    } catch (e) {
      debugPrint('Failed to create disc: $e');
      rethrow;
    }
  }

  /// Remove a disc by ID via backend API
  Future<void> remove(String id) async {
    try {
      await _api.deleteDisc(id);
      await _loadFromBackend();
    } catch (e) {
      debugPrint('Failed to delete disc: $e');
      rethrow;
    }
  }

  /// Refresh discs from backend
  Future<void> refresh({String? playerId}) async {
    if (playerId != null) {
      _currentPlayerId = playerId;
    }
    await _loadFromBackend();
  }
}
