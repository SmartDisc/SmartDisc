import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_service.dart';
import '../services/disc_service.dart';
import '../services/auth_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';
import '../widgets/stat_card.dart';
import '../models/wurf.dart';

enum StatMetric {
  rotation,
  height,
  acceleration,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final api = ApiService();

  // DiscService-backed selectable discs
  final _discSvc = DiscService.instance();
  List<String> discNames = [];
  Map<String, String> discNameToId = {}; // Map name -> id
  String? selectedDiscId; // null = "Alle", otherwise the disc ID
  StatMetric selectedMetric = StatMetric.rotation;
  Future<List<Wurf>>? _wurfeF;
  Future<Map<String, dynamic>>? _statsF;
  bool _localeReady = false;
  bool _isInitialized = false;
  String? _currentUserRole; // Store role for _reload()

  @override
  void initState() {
    super.initState();
    // Initialize futures immediately to prevent LateInitializationError
    _wurfeF = Future.value(<Wurf>[]);
    _statsF = Future.value(<String, dynamic>{});
    
    initializeDateFormatting('de_AT').then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _loadUserAndDiscs();
  }

  Future<void> _loadUserAndDiscs() async {
    final auth = AuthService();
    final role = await auth.currentUserRole();
    final playerId = role == 'player' ? await auth.currentUserId() : null;
    setState(() => _currentUserRole = role);
    await _initDiscs(playerId: playerId);
    if (mounted) {
      _reload();
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _initDiscs({String? playerId}) async {
    await _discSvc.init(playerId: playerId);
    await _updateDiscLists();
    _discSvc.discs.addListener(() async {
      await _updateDiscLists();
      // Reload data when discs change (e.g., after assignment)
      _reload();
    });
  }

  Future<void> _updateDiscLists() async {
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
    
    setState(() {
      discNames = names;
      discNameToId = nameToId;
      if (selectedDiscId != null) {
        final stillExists = nameToId.values.contains(selectedDiscId);
        if (!stillExists) {
          selectedDiscId = null;
        }
      }
    });
  }

  void _reload({String? playerId}) {
    // Für Player: playerId NICHT übergeben - Backend filtert automatisch basierend auf Token
    // Für Trainer: playerId kann optional übergeben werden, um einen spezifischen Player zu filtern
    final role = _currentUserRole;
    final finalPlayerId = (role == 'trainer' && playerId != null) ? playerId : null;
    
    _wurfeF = api.getWuerfe(limit: 50, scheibeId: selectedDiscId, playerId: finalPlayerId);
    _statsF = api.getSummary(scheibeId: selectedDiscId, playerId: finalPlayerId);
    setState(() {});
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
    // Defensive check: ensure futures are initialized
    if (!_isInitialized || _wurfeF == null || _statsF == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Wurf>>(
        future: _wurfeF!,
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
                      value: selectedDiscId,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Alle')),
                        ...discNames.map((name) => DropdownMenuItem<String?>(
                          value: discNameToId[name],
                          child: Text(name),
                        )),
                      ],
                      onChanged: (v) {
                        setState(() => selectedDiscId = v);
                        _reload(); // Reload ohne playerId - Backend filtert automatisch
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // KPI grid — responsive columns using Wrap to avoid forcing tall intrinsic heights
              LayoutBuilder(builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                // target two columns on narrow, up to four on wide
                final cols = w < 420 ? 2 : (w < 900 ? 3 : 4);
                final spacing = 12.0;
                final itemW = (w - (cols - 1) * spacing) / cols;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    StatCard(
                      icon: Icons.history_rounded,
                      label: 'Disc / Time',
                      value: latest != null
                          ? '${latest.scheibeId ?? 'DISC'}\n${_formatGermanTimestamp(latest.erstelltAm)}'
                          : '-',
                      sublabel: 'Latest',
                    ),
                    StatCard(
                      icon: Icons.refresh_rounded,
                      label: 'Rotation',
                      value: latest != null && latest.rotation != null
                          ? '${latest.rotation!.toStringAsFixed(2)} rps\n${(latest.rotation! * 60).toStringAsFixed(0)} rpm'
                          : '-',
                      sublabel: 'Latest measurement',
                    ),
                    StatCard(
                      icon: Icons.height_rounded,
                      label: 'Height',
                      value: latest != null && latest.hoehe != null
                          ? '${latest.hoehe!.toStringAsFixed(2)} m'
                          : '-',
                      sublabel: 'Latest measurement',
                    ),
                    StatCard(
                      icon: Icons.speed_rounded,
                      label: 'Acceleration',
                      value: latest != null && latest.accelerationMax != null
                          ? '${latest.accelerationMax!.toStringAsFixed(2)} m/s²'
                          : '-',
                      sublabel: 'Maximum acceleration',
                    ),
                  ].map((c) => SizedBox(width: itemW.clamp(140.0, 420.0), child: c)).toList(),
                );
              }),

              const SizedBox(height: 24),
              Text('Latest throws', style: AppFont.headline),

              const SizedBox(height: 6),
              // Show which disc these throws belong to
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Disc: ${selectedDiscId == null ? "Alle" : discNameToId.entries.firstWhere((e) => e.value == selectedDiscId, orElse: () => MapEntry("", selectedDiscId ?? "")).key}',
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
