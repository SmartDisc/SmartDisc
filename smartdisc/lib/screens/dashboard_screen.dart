import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:math' as math_random;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_service.dart';
import '../services/disc_service.dart';
import '../services/auth_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';
import '../widgets/stat_card.dart';
import '../widgets/highscore_helper.dart';
import '../models/wurf.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum StatMetric {
  rotation,
  height,
  acceleration,
}

class _DashboardScreenState extends State<DashboardScreen> {
  final api = ApiService();

  // DiscService-backed selectable discs
  final _discSvc = DiscService.instance();
  List<String> discNames = List.generate(10, (i) => 'DISC-${(i + 1).toString().padLeft(2, '0')}');
  Map<String, String> discNameToId = {}; // Map name -> id
  String? selectedDiscId; // null = "Alle", otherwise the disc ID
  StatMetric selectedMetric = StatMetric.rotation;
  late Future<List<Wurf>> _wurfeF;
  late Future<Map<String, dynamic>> _statsF;
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('de_AT').then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _reload();
    _initDiscs();
  }

  Future<void> _initDiscs() async {
    await _discSvc.init();
    _updateDiscLists();
    // Listen for changes (e.g., when user edits discs in Discs screen)
    _discSvc.discs.addListener(() {
      _updateDiscLists();
      _reload();
    });
  }

  void _updateDiscLists() {
    final discList = _discSvc.discs.value;
    final names = <String>[];
    final nameToId = <String, String>{};
    
    for (final disc in discList) {
      final id = (disc['id'] as String?) ?? '';
      final name = (disc['name'] as String?) ?? id;
      if (id.isNotEmpty && name.isNotEmpty) {
        names.add(name);
        nameToId[name] = id;
      }
    }
    
    if (names.isEmpty) {
      // Fallback: generate default disc names
      names.addAll(List.generate(10, (i) => 'DISC-${(i + 1).toString().padLeft(2, '0')}'));
      for (final name in names) {
        nameToId[name] = name; // Use name as ID for fallback
      }
    }
    
    setState(() {
      discNames = names;
      discNameToId = nameToId;
      // Wenn selectedDiscId nicht mehr in der Liste ist, auf "Alle" setzen
      if (selectedDiscId != null) {
        final stillExists = nameToId.values.contains(selectedDiscId);
        if (!stillExists) {
          selectedDiscId = null;
        }
      }
    });
  }

  void _reload() {
    _wurfeF = api.getWuerfe(limit: 50, scheibeId: selectedDiscId);
    _statsF = api.getSummary(scheibeId: selectedDiscId);
    setState(() {});
  }

  Future<void> _createTestThrow() async {
    try {
      final auth = AuthService();
      final userId = await auth.currentUserId();
      
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte einloggen')),
        );
        return;
      }

      final rnd = math_random.Random();
      // Wenn "Alle" ausgewählt, verwende erste Disc für Test-Wurf
      final discForThrow = selectedDiscId ?? (discNameToId.values.isNotEmpty ? discNameToId.values.first : discNames.first);
      // Erstelle einen Wurf mit zufälligen Werten (hohe Werte für bessere Chance auf Highscore)
      final result = await api.createThrow(
        scheibeId: discForThrow,
        playerId: userId,
        rotation: 5.0 + rnd.nextDouble() * 10, // 5-15 rps
        height: 2.0 + rnd.nextDouble() * 5, // 2-7 m
        accelerationMax: 8.0 + rnd.nextDouble() * 10, // 8-18 m/s²
      );

      // Prüfe ob neuer Rekord
      if (result['is_new_record'] == true && result['record_type'] != null) {
        showHighscorePopup(context, result['record_type'] as String);
      }

      // Reload data
      _reload();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }


  String _formatGermanTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final local = dt.toLocal();
    if (!_localeReady) {
      // While locale data not yet initialized, fallback to a simple ISO time slice
      return local.toIso8601String().replaceFirst('T', ' ').substring(0, 19);
    }
    return DateFormat('dd.MM.yyyy HH:mm:ss', 'de_AT').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Wurf>>(
        future: _wurfeF,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = s.data ?? [];
          // (Past sessions display removed from dashboard - use History screen)

          // Responsive horizontal padding so narrow phones don't look cramped
          final screenW = MediaQuery.of(context).size.width;
          final horizontalPadding = screenW < 380 ? 12.0 : 16.0;

          // Compute KPIs for the selected disc
          final latest = items.isNotEmpty ? items.first : null;
          
            // Removed unused KPI aggregation variables
            // final avgSpeedMps = last10.isEmpty
            //     ? 0
            //     : last10
            //             .map((w) => w.geschwindigkeit ?? 0)
            //             .fold<double>(0, (a, b) => a + b) /
            //         last10.length;
            // final avgSpeedMph = _mpsToMph(avgSpeedMps);
            // final maxDistM = items.fold<double>(
            //     0, (mx, w) => (w.entfernung ?? 0) > mx ? (w.entfernung ?? 0) : mx);
            // final maxDistFt = _mToFt(maxDistM);
            // final avgRps = last10.isEmpty
            //     ? 0
            //     : last10
            //             .map((w) => w.geschwindigkeit ?? 0)
            //             .fold<double>(0, (a, b) => a + b) /
            //         last10.length;
            // final avgRpm = avgRps * 60.0;
            // final totalThrows = items.length;

          return ListView(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
            children: [
              // 3D Frisbee preview directly under the header — make height responsive
              LayoutBuilder(builder: (ctx, constraints) {
                // Limit the preview to a reasonable height but allow it to scale with width
                final maxW = constraints.maxWidth;
                final computedHeight = math.min(320, maxW * 0.55).toDouble();
                return SizedBox(
                  height: computedHeight,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: const ModelViewer(
                      src: 'assets/models/SmartDisc.glb',
                      alt: 'Frisbee model',
                      ar: false,
                      autoRotate: true,
                      cameraControls: true,
                      cameraOrbit: '0deg 65deg 105%',
                      exposure: 1.0,
                      shadowIntensity: 0.0,
                      disableZoom: false,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),
              // Disc selector
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textSecondary.withAlpha((0.15 * 255).round())),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedDiscId != null ? discNameToId.entries.firstWhere((e) => e.value == selectedDiscId, orElse: () => discNameToId.entries.first).key : null,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Alle Discs'),
                        ),
                        ...discNames.map((name) => DropdownMenuItem<String?>(
                          value: name,
                          child: Text(name),
                        )),
                      ],
                      onChanged: (v) {
                        setState(() {
                          selectedDiscId = v != null ? discNameToId[v] : null;
                        });
                        _reload();
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Metric selector
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textSecondary.withAlpha((0.15 * 255).round())),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<StatMetric>(
                      value: selectedMetric,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem<StatMetric>(
                          value: StatMetric.rotation,
                          child: Text('Rotation'),
                        ),
                        DropdownMenuItem<StatMetric>(
                          value: StatMetric.height,
                          child: Text('Höhe'),
                        ),
                        DropdownMenuItem<StatMetric>(
                          value: StatMetric.acceleration,
                          child: Text('Beschleunigung'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => selectedMetric = v);
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Statistics based on selected metric and disc
              FutureBuilder<Map<String, dynamic>>(
                future: _statsF,
                builder: (context, statsSnapshot) {
                  final stats = statsSnapshot.data ?? {};
                  final discLabel = selectedDiscId != null 
                      ? discNameToId.entries.firstWhere((e) => e.value == selectedDiscId, orElse: () => discNameToId.entries.first).key
                      : 'Alle Discs';
                  
                  return LayoutBuilder(builder: (ctx, constraints) {
                    final w = constraints.maxWidth;
                    final cols = w < 420 ? 2 : (w < 900 ? 3 : 4);
                    final spacing = 12.0;
                    final itemW = (w - (cols - 1) * spacing) / cols;
                    
                    // Get values based on selected metric
                    String metricLabel;
                    IconData metricIcon;
                    String avgValue;
                    String maxValue;
                    
                    switch (selectedMetric) {
                      case StatMetric.rotation:
                        metricLabel = 'Rotation';
                        metricIcon = Icons.refresh_rounded;
                        final avg = (stats['rotationAvg'] as num?)?.toDouble() ?? 0.0;
                        final max = (stats['rotationMax'] as num?)?.toDouble() ?? 0.0;
                        avgValue = '${avg.toStringAsFixed(2)} rps\n${(avg * 60).toStringAsFixed(0)} rpm';
                        maxValue = '${max.toStringAsFixed(2)} rps\n${(max * 60).toStringAsFixed(0)} rpm';
                        break;
                      case StatMetric.height:
                        metricLabel = 'Höhe';
                        metricIcon = Icons.height_rounded;
                        final avg = (stats['heightAvg'] as num?)?.toDouble() ?? 0.0;
                        final max = (stats['heightMax'] as num?)?.toDouble() ?? 0.0;
                        avgValue = '${avg.toStringAsFixed(2)} m';
                        maxValue = '${max.toStringAsFixed(2)} m';
                        break;
                      case StatMetric.acceleration:
                        metricLabel = 'Beschleunigung';
                        metricIcon = Icons.speed_rounded;
                        final avg = (stats['accelerationAvg'] as num?)?.toDouble() ?? 0.0;
                        final max = (stats['accelerationMax'] as num?)?.toDouble() ?? 0.0;
                        avgValue = '${avg.toStringAsFixed(2)} m/s²';
                        maxValue = '${max.toStringAsFixed(2)} m/s²';
                        break;
                    }
                    
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        StatCard(
                          icon: Icons.storage_rounded,
                          label: 'Disc',
                          value: discLabel,
                          sublabel: 'Ausgewählt',
                        ),
                        StatCard(
                          icon: metricIcon,
                          label: 'Durchschnitt $metricLabel',
                          value: avgValue,
                          sublabel: 'Mittelwert',
                        ),
                        StatCard(
                          icon: metricIcon,
                          label: 'Maximum $metricLabel',
                          value: maxValue,
                          sublabel: 'Höchster Wert',
                        ),
                        StatCard(
                          icon: Icons.assessment_rounded,
                          label: 'Anzahl Würfe',
                          value: '${stats['count'] ?? 0}',
                          sublabel: 'Gesamt',
                        ),
                      ].map((c) => SizedBox(width: itemW.clamp(140.0, 420.0), child: c)).toList(),
                    );
                  });
                },
              ),

              const SizedBox(height: 24),
              // Test Button für Highscore
              ElevatedButton.icon(
                onPressed: _createTestThrow,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Test Wurf erstellen (Highscore Demo)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bluePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              Text('Latest throws', style: AppFont.headline),

              const SizedBox(height: 6),
              // Show which disc these throws belong to
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Disc: ${selectedDiscId != null 
                      ? discNameToId.entries.firstWhere((e) => e.value == selectedDiscId, orElse: () => discNameToId.entries.first).key
                      : 'Alle Discs'}',
                  style: AppFont.subheadline,
                ),
              ),

              const SizedBox(height: 4),
              if (items.isEmpty)
                const ListTile(title: Text('No throws yet'))
              else
                ...items.take(10).map((w) {
                  final rot = w.rotation != null ? '${w.rotation!.toStringAsFixed(2)} rps' : null;
                  final height = w.hoehe != null ? '${w.hoehe!.toStringAsFixed(2)} m' : null;
                  final accel = w.accelerationMax != null ? '${w.accelerationMax!.toStringAsFixed(2)} m/s²' : null;
                  
                  final measurements = <String>[];
                  if (rot != null) measurements.add('Rot: $rot');
                  if (height != null) measurements.add('H: $height');
                  if (accel != null) measurements.add('A: $accel');
                  
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      dense: true,
                      title: Text(w.scheibeId ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (measurements.isNotEmpty)
                            Text(measurements.join(' • '), style: AppFont.subheadline),
                          const SizedBox(height: 2),
                          Text(_formatGermanTimestamp(w.erstelltAm), style: AppFont.subheadline, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),
              const SizedBox.shrink(),
            ],
          );
        },
      ),
    ),
  );
  }
}
