import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../styles/app_font.dart';
import '../services/api_service.dart';
import '../models/wurf.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  late Future<List<Wurf>> _wurfeF;
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('de_AT').then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _reload();
  }

  void _reload() {
    _wurfeF = _api.getWuerfe(limit: 200);
    setState(() {});
  }

  String _formatGermanTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final local = dt.toLocal();
    if (!_localeReady) return local.toIso8601String().replaceFirst('T', ' ').substring(0, 19);
    return DateFormat('dd.MM.yyyy HH:mm:ss', 'de_AT').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<Wurf>>(
        future: _wurfeF,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = s.data ?? [];

          // Add an extra synthetic throw about one week ago so it appears in history
          final oneWeekAgo = DateTime.now().toUtc().subtract(const Duration(days: 7));
          final extraId = 'manual-old-${oneWeekAgo.millisecondsSinceEpoch}';
          // Only add if not already present
          final hasExtra = items.any((w) => w.id == extraId);
          final allItems = List<Wurf>.from(items);
          if (!hasExtra) {
            allItems.add(Wurf(
              id: extraId,
              scheibeId: 'DISC-01',
              entfernung: 27.5,
              geschwindigkeit: 9.8,
              rotation: 4.2,
              hoehe: 2.1,
              erstelltAm: oneWeekAgo.toIso8601String(),
            ));
          }

          if (allItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.history, size: 72),
                  SizedBox(height: 12),
                  Text('History', style: AppFont.headline),
                  SizedBox(height: 8),
                  Text('No throws or sessions yet.'),
                ],
              ),
            );
          }

          // Group throws into sessions by date (yyyy-MM-dd)
          final Map<String, List<Wurf>> sessionsMap = {};
          for (final w in allItems) {
            final dt = w.erstelltAm == null ? null : DateTime.tryParse(w.erstelltAm!);
            final local = dt?.toLocal();
            final key = local != null ? DateFormat('yyyy-MM-dd').format(local) : 'unknown';
            sessionsMap.putIfAbsent(key, () => []).add(w);
          }

          final sessionKeys = sessionsMap.keys.toList()..sort((a, b) => b.compareTo(a));

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sessionKeys.length,
              itemBuilder: (ctx, idx) {
                final key = sessionKeys[idx];
                final list = sessionsMap[key]!;
                final count = list.length;
                final speeds = list.where((x) => x.geschwindigkeit != null).map((x) => x.geschwindigkeit!).toList();
                final avgSpeed = speeds.isEmpty ? 0.0 : speeds.fold<double>(0, (a, b) => a + b) / speeds.length;
                final maxDist = list.map((x) => x.entfernung ?? 0).fold<double>(0, (mx, v) => v > mx ? v : mx);

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    title: Text('$key • $count throws'),
                    subtitle: Text('Avg: ${avgSpeed.toStringAsFixed(2)} m/s • Max d: ${maxDist.toStringAsFixed(1)} m'),
                    children: list.map((w) => ListTile(
                          title: Text(_formatGermanTimestamp(w.erstelltAm)),
                          subtitle: Text('v=${w.geschwindigkeit ?? '-'} m/s   •   d=${w.entfernung ?? '-'} m'),
                        )).toList(),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
