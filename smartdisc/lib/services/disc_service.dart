import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscService {
  static const _kKey = 'smartdisc_discs';
  static final DiscService _instance = DiscService._internal();
  factory DiscService.instance() => _instance;
  DiscService._internal();

  final ValueNotifier<List<Map<String, dynamic>>> discs = ValueNotifier([]);
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kKey);
    if (s != null) {
      try {
        final parsed = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
        discs.value = parsed;
      } catch (_) {
        discs.value = [];
      }
    } else {
      // If no stored discs, initialize with 10 default DISC-01..DISC-10
      final now = DateTime.now().toUtc().toIso8601String();
      discs.value = List.generate(10, (i) => {
            'name': 'DISC-${(i + 1).toString().padLeft(2, '0')}',
            'addedAt': now,
          });
      // persist defaults
      await sp.setString(_kKey, jsonEncode(discs.value));
    }
    _initialized = true;
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, jsonEncode(discs.value));
  }

  Future<void> add(String name) async {
    final entry = {'name': name, 'addedAt': DateTime.now().toUtc().toIso8601String()};
    discs.value = [entry, ...discs.value];
    await _save();
  }

  Future<void> removeAt(int index) async {
    final copy = List<Map<String, dynamic>>.from(discs.value);
    if (index < 0 || index >= copy.length) return;
    copy.removeAt(index);
    discs.value = copy;
    await _save();
  }
}
