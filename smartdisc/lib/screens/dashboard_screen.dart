import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_service.dart';
import '../services/disc_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';
import '../widgets/stat_card.dart';
import '../models/wurf.dart';
import '../models/ble_disc_measurement.dart';
import '../models/ui_throw.dart';
import '../services/throw_repository.dart';
import '../utils/responsive.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final api = ApiService();
  final _discSvc = DiscService.instance();
  List<String> discs = [];
  String selectedDisc = '';
  Future<List<Wurf>> _wurfeF = Future.value([]);
  bool _localeReady = false;
  VoidCallback? _discsListener;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  int _totalThrows = 0;
  String? _lastUsedDisc;
  bool _newDataAvailable = false;
  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0;
  bool _shouldRestoreScroll = false;
  final List<UiThrow> _liveThrows = [];
  late final ThrowRepository _throwRepository;
  Timer? _simulationTimer;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('de_AT').then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _reload();
    _initDiscs();
    _startAutoRefresh();
    _throwRepository = ThrowRepository(
      apiService: api,
      onStateChanged: (list) {
        if (!mounted) return;
        setState(() {
          _liveThrows
            ..clear()
            ..addAll(list);
        });
      },
    );
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted && !_isRefreshing) {
        _reload(silent: true);
      }
    });
  }

  Future<void> _initDiscs() async {
    await _discSvc.init();
    final stored = _discSvc.discs.value.map((m) => (m['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
    setState(() {
      discs = stored;
      if (discs.isNotEmpty && !discs.contains(selectedDisc)) {
        selectedDisc = discs.first;
      }
    });
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
    _simulationTimer?.cancel();
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
    // Load from backend so stored data remains visible after refresh or app restart (limit allows enough history).
    final newWurfeF = api.getWuerfe(limit: 100, scheibeId: selectedDisc);
    try {
      final allWurfe = await api.getWuerfe(limit: 100);
      final newTotal = allWurfe.length;
      final wurfeList = await newWurfeF;
      if (mounted) {
        _savedScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0;
        _shouldRestoreScroll = true;
        setState(() {
          _wurfeF = Future.value(wurfeList);
          // Clear live buffer on reload so backend data is the source of truth (no visible duplicates).
          _liveThrows.clear();
          if (newTotal > _totalThrows && _totalThrows > 0) {
            _newDataAvailable = true;
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _newDataAvailable = false);
            });
          }
          _totalThrows = newTotal;
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
      return local.toIso8601String().replaceFirst('T', ' ').substring(0, 19);
    }
    return DateFormat('dd.MM.yyyy HH:mm:ss', 'de_AT').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundAlt,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<Wurf>>(
            future: _wurfeF,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final baseItems = s.data ?? [];
              // Prepend any live throws captured from BLE (not yet persisted or just persisted)
              final liveItems = _liveThrows.map((t) => t.wurf).toList();
              final items = [...liveItems, ...baseItems];
              final responsive = context.responsive;
              final latest = items.isNotEmpty ? items.first : null;

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
                      // Hero header
                      _buildHeroHeader(responsive),
                      const SizedBox(height: 20),

                      // Disc selector
                      _buildDiscSelector(),

                      const SizedBox(height: 24),

                      // Section: Key metrics
                      Text('Key metrics', style: AppFont.headlineSmall),
                      const SizedBox(height: 12),
                      LayoutBuilder(builder: (ctx, constraints) {
                        final w = constraints.maxWidth;
                        final cols = responsive.getGridColumns(mobile: 2, tablet: 3, desktop: 4);
                        const spacing = 12.0;
                        final itemW = (w - (cols - 1) * spacing) / cols;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            StatCard(
                              label: 'Last throw',
                              value: latest != null
                                  ? _formatGermanTimestamp(latest.erstelltAm)
                                  : '—',
                              sublabel: selectedDisc,
                            ),
                            StatCard(
                              label: 'Rotation',
                              value: latest != null && latest.rotation != null
                                  ? '${latest.rotation!.toStringAsFixed(2)} rps'
                                  : '—',
                              sublabel: latest != null && latest.rotation != null
                                  ? '${(latest.rotation! * 60).toStringAsFixed(0)} rpm'
                                  : 'Latest',
                            ),
                            StatCard(
                              label: 'Height',
                              value: latest != null && latest.hoehe != null
                                  ? '${latest.hoehe!.toStringAsFixed(2)} m'
                                  : '—',
                              sublabel: 'Latest',
                            ),
                            StatCard(
                              label: 'Acceleration',
                              value: latest != null && latest.accelerationMax != null
                                  ? '${latest.accelerationMax!.toStringAsFixed(2)} m/s²'
                                  : '—',
                              sublabel: 'Max',
                            ),
                          ].map((card) => SizedBox(width: itemW.clamp(140.0, 420.0), child: card)).toList(),
                        );
                      }),

                      const SizedBox(height: 28),

                      // Debug: simulation controls (debug builds only)
                      if (kDebugMode) ...[
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _simulateSingleThrow,
                              child: const Text('Simulate Throw'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSimulating ? _stopAutoSimulation : _startAutoSimulation,
                              child: Text(_isSimulating ? 'Stop Auto Simulation' : 'Start Auto Simulation'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Section: Latest throws
                      Row(
                        children: [
                          Text('Latest throws', style: AppFont.headlineSmall),
                          if (_newDataAvailable) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('New', style: AppFont.caption.copyWith(
                                color: AppColors.textOnAccent,
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Disc: $selectedDisc', style: AppFont.caption),
                      const SizedBox(height: 12),

                      if (items.isEmpty)
                        _buildEmptyThrows()
                      else
                        ...items.map((w) => _buildThrowCard(w)),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Inject a live measurement from BLE for immediate feedback. Long-term visibility comes from backend (reload loads stored data).
  void addLiveMeasurementFromBle(BleDiscMeasurement m) {
    // Optional: only show when current disc filter matches.
    if (selectedDisc.isNotEmpty && m.scheibeId != selectedDisc) {
      return;
    }
    _throwRepository.addBleMeasurement(m);
  }

  /// Create a fake BLE measurement for debug/testing.
  BleDiscMeasurement _createFakeMeasurement() {
    final rnd = math.Random();
    // Use selected disc if available, otherwise fall back to a generic id.
    final discId = selectedDisc.isNotEmpty ? selectedDisc : 'DEBUG-DISC-01';

    // Rotation: 3–9 rps
    final rotation = 3.0 + rnd.nextDouble() * 6.0;

    // Height: 1–5 m
    final height = 1.0 + rnd.nextDouble() * 4.0;

    // Acceleration components: -2..2 m/s², max magnitude ~9–20 m/s²
    final ax = -2.0 + rnd.nextDouble() * 4.0;
    final ay = -2.0 + rnd.nextDouble() * 4.0;
    final az = 8.0 + rnd.nextDouble() * 6.0; // keep Z roughly gravity-like

    final accelMax = math.sqrt(ax * ax + ay * ay + az * az);

    return BleDiscMeasurement(
      scheibeId: discId,
      hoehe: height,
      rotation: rotation,
      accelerationX: ax,
      accelerationY: ay,
      accelerationZ: az,
      accelerationMax: accelMax,
    );
  }

  void _simulateSingleThrow() {
    final m = _createFakeMeasurement();
    addLiveMeasurementFromBle(m);
  }

  void _startAutoSimulation() {
    if (_isSimulating) return;
    _isSimulating = true;

    // Fire one immediately for quick feedback.
    _simulateSingleThrow();

    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _simulateSingleThrow();
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _stopAutoSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulating = false;
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildHeroHeader(Responsive responsive) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Dashboard', style: AppFont.headlineSmall.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscSelector() {
    final effectiveValue = selectedDisc.isEmpty && discs.isNotEmpty
        ? discs.first
        : (discs.contains(selectedDisc) ? selectedDisc : (discs.isNotEmpty ? discs.first : null));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: effectiveValue,
          hint: Text('Select disc', style: AppFont.subheadline.copyWith(color: AppColors.textMuted)),
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: discs
              .map((d) => DropdownMenuItem<String?>(
                    value: d,
                    child: Text(d, style: AppFont.subheadline),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => selectedDisc = v);
            _reload();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyThrows() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Text('No throws yet', style: AppFont.subheadline),
          const SizedBox(height: 6),
          Text('Throws will appear here when you use your disc', style: AppFont.caption),
        ],
      ),
    );
  }

  Widget _buildThrowCard(Wurf w) {
    final rot = w.rotation != null ? '${w.rotation!.toStringAsFixed(2)} rps' : null;
    final height = w.hoehe != null ? '${w.hoehe!.toStringAsFixed(2)} m' : null;
    final accel = w.accelerationMax != null ? '${w.accelerationMax!.toStringAsFixed(2)} m/s²' : null;
    final measurements = <String>[];
    if (rot != null) measurements.add(rot);
    if (height != null) measurements.add(height);
    if (accel != null) measurements.add(accel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(w.scheibeId ?? '—', style: AppFont.subheadline.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                      if (measurements.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(measurements.join(' · '), style: AppFont.caption),
                      ],
                      const SizedBox(height: 2),
                      Text(_formatGermanTimestamp(w.erstelltAm), style: AppFont.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
