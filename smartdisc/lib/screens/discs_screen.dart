import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscsScreen extends StatefulWidget {
  const DiscsScreen({super.key});

  @override
  State<DiscsScreen> createState() => _DiscsScreenState();
}

class _DiscsScreenState extends State<DiscsScreen> {
  static const _kKey = 'smartdisc_discs';

  List<Map<String, dynamic>> _discs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kKey);
    if (s != null) {
      try {
        final parsed = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
        _discs = parsed;
      } catch (_) {
        _discs = [];
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, jsonEncode(_discs));
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _addDisc() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add disc'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'DISC-01 or MyDisc'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    setState(() {
      _discs.insert(0, {'name': name, 'addedAt': DateTime.now().toUtc().toIso8601String()});
    });
    await _save();
  }

  Future<void> _removeDisc(int idx) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete disc?'),
        content: Text('Delete "${_discs[idx]['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _discs.removeAt(idx));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Discs')),
      body: _discs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.sports_baseball, size: 72, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No discs yet', style: TextStyle(fontSize: 18)),
                    SizedBox(height: 6),
                    Text('Tap + to add a disc. You can delete discs later.'),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _discs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final d = _discs[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(d['name'] ?? '-'),
                    subtitle: Text('Added: ${_formatDate(d['addedAt'] ?? '')}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeDisc(i),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDisc,
        tooltip: 'Add disc',
        child: const Icon(Icons.add),
      ),
    );
  }
}
