import 'package:flutter/material.dart';
// SharedPreferences usage moved to DiscService
import '../services/disc_service.dart';

class DiscsScreen extends StatefulWidget {
  const DiscsScreen({super.key});

  @override
  State<DiscsScreen> createState() => _DiscsScreenState();
}

class _DiscsScreenState extends State<DiscsScreen> {
  final _svc = DiscService.instance();
  List<Map<String, dynamic>> _discs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _svc.init();
    _discs = List<Map<String, dynamic>>.from(_svc.discs.value);
    // Listen for external changes so UI updates when discs change elsewhere
    _svc.discs.addListener(() {
      setState(() {
        _discs = List<Map<String, dynamic>>.from(_svc.discs.value);
      });
    });
    setState(() => _loading = false);
  }

  // Save handled by DiscService; no-op kept for compatibility if needed later.

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
    await _svc.add(name);
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
    await _svc.removeAt(idx);
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
