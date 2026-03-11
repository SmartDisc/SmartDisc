import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_service.dart';
import '../services/disc_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';
import '../widgets/stat_card.dart';
import '../models/wurf.dart';
import '../utils/responsive.dart';

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
  Future<List<Wurf>> _wurfeF = Future.value([]);
  bool _localeReady = false;
  VoidCallback? _discsListener;
  
  // Auto-refresh
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  int _totalThrows = 0;
  String? _lastUsedDisc;
  bool _newDataAvailable = false;

  // Preserve scroll position when data reloads
  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0;
  bool _shouldRestoreScroll = false;


  @override
  void initState() {
    super.initState();
    initializeDateFormatting('de_AT').then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _reload();
    _initDiscs();
    _startAutoRefresh();
  }
  
  void _startAutoRefresh() {
    // Auto-refresh every 8 seconds so list doesn't constantly jump
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted && !_isRefreshing) {
        _reload(silent: true);
      }
    });
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
    _refreshTimer?.cancel();
    _scrollController.dispose();
    if (_discsListener != null) {
      _discSvc.discs.removeListener(_discsListener!);
    }
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      _isRefreshing = true;
    }
    
    final newWurfeF = api.getWuerfe(scheibeId: selectedDisc); // No limit - get all
   
    // Get total count
    try {
      final allWurfe = await api.getWuerfe(); // No limit - get all
      final newTotal = allWurfe.length;
      final wurfeList = await newWurfeF;
      
      if (mounted) {
        // Save scroll position so it can be restored after rebuild
        _savedScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0;
        _shouldRestoreScroll = true;
        setState(() {
          _wurfeF = Future.value(wurfeList);
          
          // Check if we have new data
          if (newTotal > _totalThrows && _totalThrows > 0) {
            _newDataAvailable = true;
            // Clear indicator after 2 seconds
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() => _newDataAvailable = false);
              }
            });
          }
          
          _totalThrows = newTotal;
          
          // Track last used disc
          if (wurfeList.isNotEmpty) {
            _lastUsedDisc = wurfeList.first.scheibeId;
          }
          
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _wurfeF = newWurfeF;
          _isRefreshing = false;
        });
      }
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
          final responsive = context.responsive;

          // Compute KPIs for the selected disc
          final latest = items.isNotEmpty ? items.first : null;

          // Restore scroll position after a reload (runs once per reload)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _shouldRestoreScroll && _scrollController.hasClients) {
              _scrollController.jumpTo(_savedScrollOffset);
              _shouldRestoreScroll = false;
            }
          });

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.horizontalPadding,
                  vertical: responsive.verticalPadding,
                ),
            children: [
              // 3D Frisbee preview — make height responsive
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
                final cols = responsive.getGridColumns(mobile: 2, tablet: 3, desktop: 4);
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
                ...items.map((w) {
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
            ],
              ),
            ),
          );
        },
      ),
    ),
  );
  }
}
