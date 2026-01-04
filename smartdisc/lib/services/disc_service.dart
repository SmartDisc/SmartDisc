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

  Future<void> init() async {
    if (_initialized) return;
    await _loadFromBackend();
    _initialized = true;
  }

  /// Load discs from backend, with optional cache fallback
  Future<void> _loadFromBackend() async {
    try {
      final items = await _api.getDiscs();
      discs.value = items;
      await _saveCache();
    } catch (e) {
      // If backend fails, try to load from cache
      debugPrint('Failed to load discs from backend: $e');
      await _loadFromCache();
    }
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
  Future<void> refresh() async {
    await _loadFromBackend();
  }
}
