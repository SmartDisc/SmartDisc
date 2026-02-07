import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_service.dart';
import '../services/disc_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';
import '../widgets/stat_card.dart';
import '../models/wurf.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final api = ApiService();

  // DiscService-backed selectable discs
  final _discSvc = DiscService.instance();
  List<String> discs = [];
  String selectedDisc = '';
  late Future<List<Wurf>> _wurfeF;
  bool _localeReady = false;
  VoidCallback? _discsListener;


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
    // populate local discs list from stored data
    final stored = _discSvc.discs.value.map((m) => (m['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
    setState(() {
      discs = stored;
      if (discs.isNotEmpty && !discs.contains(selectedDisc)) {
        selectedDisc = discs.first;
      }
    });
    // Listen for changes (e.g., when user edits discs in Discs screen)
    _discsListener = () {
      if (!mounted) return;
      final vals = _discSvc.discs.value.map((m) => (m['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      setState(() {
        discs = vals;
        if (discs.isEmpty || !discs.contains(selectedDisc)) {
          selectedDisc = discs.isNotEmpty ? discs.first : '';
        }
      });
      _reload();
    };
    _discSvc.discs.addListener(_discsListener!);
  }

  @override
  void dispose() {
    if (_discsListener != null) {
      _discSvc.discs.removeListener(_discsListener!);
    }
    super.dispose();
  }

  void _reload() {
    _wurfeF = api.getWuerfe(limit: 50, scheibeId: selectedDisc);
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
                    child: DropdownButton<String>(
                      value: selectedDisc,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: discs
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedDisc = v);
                        _reload();
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
                child: Text('Disc: $selectedDisc', style: AppFont.subheadline),
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
