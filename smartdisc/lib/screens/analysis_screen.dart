import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/disc_service.dart';
import '../models/wurf.dart';
import '../models/ble_disc_measurement.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';
import '../utils/export_handler.dart';
import '../utils/responsive.dart';

enum YAxisMetric {
  rotation, // Rotation
  height, // Höhe
  acceleration, // Maximum acceleration
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => AnalysisScreenState();
}

class AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();
  final DiscService _discService = DiscService.instance();
  List<Wurf> _wurfe = [];
  List<Wurf> _allWurfe = []; // Store all wurfe for filtering
  final List<Wurf> _liveWurfe = []; // Live measurements from BLE (bounded)
  bool _isLoading = true;
  YAxisMetric _selectedMetric = YAxisMetric.rotation;
  String? _selectedDisc; // null = "Alle"

  @override
  void initState() {
    super.initState();
    _initDiscs();
    _loadWurfe();
  }

  Future<void> _initDiscs() async {
    await _discService.init();
    if (mounted) {
      // Listen for disc changes and reload data
      _discService.discs.addListener(_onDiscsChanged);
    }
  }

  void _onDiscsChanged() {
    if (mounted) {
      // Reload data to get any new throws from newly added discs
      _loadWurfe();
    }
  }

  @override
  void dispose() {
    _discService.discs.removeListener(_onDiscsChanged);
    super.dispose();
  }

  Future<void> _loadWurfe() async {
    setState(() => _isLoading = true);
    try {
      // Load from backend so stored data remains visible after refresh or app restart.
      final wurfe = await _apiService.getWuerfe(limit: 500);
      // Sort by timestamp (oldest first for graph)
      wurfe.sort((a, b) {
        DateTime aTime = DateTime(1970);
        DateTime bTime = DateTime(1970);
        try {
          if (a.erstelltAm != null) aTime = DateTime.parse(a.erstelltAm!);
        } catch (_) {}
        try {
          if (b.erstelltAm != null) bTime = DateTime.parse(b.erstelltAm!);
        } catch (_) {}
        return aTime.compareTo(bTime);
      });
      setState(() {
        _allWurfe = wurfe;
        // Clear live buffer on reload so backend is source of truth (no visible duplicates when reloading).
        _liveWurfe.clear();
        _applyDiscFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  /// Inject a live measurement from BLE for immediate feedback. Long-term visibility comes from backend (Dashboard/History/Analysis load stored data on reload).
  void addLiveMeasurementFromBle(BleDiscMeasurement m) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final wurf = Wurf(
      id: 'live_${DateTime.now().microsecondsSinceEpoch}',
      scheibeId: m.scheibeId,
      rotation: m.rotation,
      hoehe: m.hoehe,
      accelerationX: m.accelerationX,
      accelerationY: m.accelerationY,
      accelerationZ: m.accelerationZ,
      accelerationMax: m.accelerationMax,
      erstelltAm: nowIso,
    );
    if (!mounted) return;
    setState(() {
      // Add to live buffer at the end (newest)
      _liveWurfe.add(wurf);
      // Keep list bounded for efficiency during continuous BLE input
      if (_liveWurfe.length > 50) {
        _liveWurfe.removeAt(0); // Remove oldest
      }
      _applyDiscFilter();
    });
  }

  String _getMetricLabel(YAxisMetric metric) {
    switch (metric) {
      case YAxisMetric.rotation:
        return 'Rotation (rps)';
      case YAxisMetric.height:
        return 'Height (m)';
      case YAxisMetric.acceleration:
        return 'Maximum Acceleration (m/s²)';
    }
  }

  String _getMetricDisplayName(YAxisMetric metric) {
    switch (metric) {
      case YAxisMetric.rotation:
        return 'Rotation';
      case YAxisMetric.height:
        return 'Height';
      case YAxisMetric.acceleration:
        return 'Acceleration';
    }
  }

  double? _getMetricValue(Wurf wurf, YAxisMetric metric) {
    switch (metric) {
      case YAxisMetric.rotation:
        return wurf.rotation;
      case YAxisMetric.height:
        return wurf.hoehe;
      case YAxisMetric.acceleration:
        return wurf.accelerationMax;
    }
  }

  Widget _buildFilterRow(Responsive responsive) {
    final discFilter = Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButton<String?>(
          value: _selectedDisc,
          hint: Row(
            children: const [
              Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('All Discs', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.primary),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: const [
                  Icon(Icons.all_inclusive, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('All Discs', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            ..._getAvailableDiscs().map((discInfo) {
              final discId = discInfo['id'] ?? '';
              final discName = discInfo['name'] ?? discId;
              return DropdownMenuItem<String?>(
                value: discId,
                child: Text(discName, style: const TextStyle(fontSize: 14)),
              );
            }),
          ],
          onChanged: (String? newValue) {
            setState(() {
              _selectedDisc = newValue;
              _applyDiscFilter();
            });
          },
        ),
      ),
    );

    final metricFilter = Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButton<YAxisMetric>(
          value: _selectedMetric,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.primary),
          items: YAxisMetric.values.map((metric) {
            IconData icon;
            switch (metric) {
              case YAxisMetric.rotation:
                icon = Icons.rotate_right;
                break;
              case YAxisMetric.height:
                icon = Icons.height;
                break;
              case YAxisMetric.acceleration:
                icon = Icons.speed;
                break;
            }
            return DropdownMenuItem<YAxisMetric>(
              value: metric,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _getMetricDisplayName(metric),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (YAxisMetric? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedMetric = newValue;
              });
            }
          },
        ),
      ),
    );

    if (responsive.isMobile) {
      return Column(
        children: [
          discFilter,
          const SizedBox(height: 8),
          metricFilter,
        ],
      );
    } else {
      return Row(
        children: [
          discFilter,
          const SizedBox(width: 12),
          metricFilter,
        ],
      );
    }
  }

  void openExportSheet() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String format = 'csv';
        bool exportAll = false;
        bool isExporting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> onExport() async {
              if (isExporting) return;
              setModalState(() => isExporting = true);
              try {
                await _exportThrows(exportAll: exportAll, format: format);
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Export failed: $e'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              } finally {
                if (mounted) setModalState(() => isExporting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export', style: AppFont.headline),
                  const SizedBox(height: 12),
                  Text('Format', style: AppFont.subheadline),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    value: 'csv',
                    groupValue: format,
                    onChanged: (v) => setModalState(() => format = v ?? 'csv'),
                    title: const Text('CSV'),
                  ),
                  const SizedBox(height: 8),
                  Text('Scope', style: AppFont.subheadline),
                  const SizedBox(height: 8),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: exportAll,
                    onChanged: (v) => setModalState(() => exportAll = v ?? false),
                    title: const Text('Export current filters'),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: exportAll,
                    onChanged: (v) => setModalState(() => exportAll = v ?? false),
                    title: const Text('Export all throws'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isExporting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isExporting ? null : onExport,
                          child: isExporting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Export'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportThrows({required bool exportAll, required String format}) async {
    if (!mounted) return;

    if (!exportAll && _wurfe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export with current filters.'),
        ),
      );
      return;
    }

    final bytes = await _apiService.exportThrows(
      format: format,
      exportAll: exportAll,
      discId: exportAll ? null : _selectedDisc,
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'smartdisc_throws_$timestamp.$format';

    await saveExportAndShare(bytes, filename, context);
  }

  List<FlSpot> _getChartSpots() {
    if (_wurfe.isEmpty) return [];

    // Simply plot each throw as a point (index as X, value as Y)
    final spots = <FlSpot>[];
    for (int i = 0; i < _wurfe.length; i++) {
      final yValue = _getMetricValue(_wurfe[i], _selectedMetric);
      if (yValue != null && yValue.isFinite) {
        spots.add(FlSpot(i.toDouble(), yValue));
      }
    }
    return spots;
  }

  List<Map<String, String>> _getAvailableDiscs() {
    // Nur Discs aus dem DiscService (Backend) anzeigen.
    // Dadurch gibt es keine doppelten Einträge wie eine zweite „1“ aus alten Wurf‑Daten.
    final discMap = <String, String>{}; // id -> display name

    for (final disc in _discService.discs.value) {
      final id = (disc['id'] as String?) ?? '';
      if (id.isNotEmpty) {
        discMap[id] = (disc['name'] as String?) ?? id;
      }
    }

    return discMap.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => (a['id'] ?? '').compareTo(b['id'] ?? ''));
  }

  void _applyDiscFilter() {
    // Merge backend data with live BLE measurements
    final combined = [..._allWurfe, ..._liveWurfe];
    
    if (_selectedDisc == null) {
      // Show all
      _wurfe = List.from(combined);
    } else {
      // Filter by selected disc.
      // Spezialfall: In der Datenbank kann die scheibe_id entweder die Disc-ID
      // (z.B. "DISC-90") oder der im Backend gepflegte Name sein (z.B. "1").
      // Daher matchen wir sowohl auf ID als auch auf den Disc-Namen.
      String? discName;
      try {
        final disc = _discService.discs.value.firstWhere(
          (d) => (d['id'] as String?) == _selectedDisc,
          orElse: () => {},
        );
        discName = disc['name'] as String?;
      } catch (_) {
        discName = null;
      }

      _wurfe = combined.where((w) {
        final id = w.scheibeId;
        if (id == null || id.isEmpty) return false;
        if (id == _selectedDisc) return true;
        if (discName != null && discName.isNotEmpty && id == discName) return true;
        return false;
      }).toList();
    }
    // Re-sort by timestamp
    _wurfe.sort((a, b) {
      final aTime = a.erstelltAm != null ? DateTime.parse(a.erstelltAm!) : DateTime(1970);
      final bTime = b.erstelltAm != null ? DateTime.parse(b.erstelltAm!) : DateTime(1970);
      return aTime.compareTo(bTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final screenHeight = MediaQuery.of(context).size.height;
    final chartHeight = responsive.isMobile 
        ? (screenHeight * 0.3).clamp(200.0, 300.0)
        : (screenHeight * 0.4).clamp(250.0, 400.0);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 1,
        title: const SizedBox.shrink(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.horizontalPadding,
              vertical: 8,
            ),
            child: _buildFilterRow(responsive),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _wurfe.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined,
                          size: 72, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No data available',
                        style: AppFont.headline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Throws will appear here once data is available.',
                        style: AppFont.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWurfe,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chart Card
                        Card(
                          elevation: 3,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            height: chartHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Text(
                                    '${_wurfe.length} throws • ${_getMetricLabel(_selectedMetric)}',
                                    style: AppFont.caption.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final spots = _getChartSpots();
                                      if (spots.isEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.show_chart,
                                                size: 48,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'No data points available',
                                                style: AppFont.body,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Select a different metric or disc filter',
                                                style: AppFont.caption,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      
                                      // Validate axis configuration
                                      final minY = _getMinY();
                                      final maxY = _getMaxY();
                                      final maxX = _getMaxX();
                                      
                                      // Safety check: ensure valid axis bounds
                                      if (!minY.isFinite || !maxY.isFinite || !maxX.isFinite || 
                                          minY >= maxY || maxX < 0) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                size: 48,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Unable to display chart',
                                                style: AppFont.body,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Invalid data range or configuration',
                                                style: AppFont.caption,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      
                                      // Calculate chart width based on data points
                                      // Show max 30 throws in viewport, ~24px per throw
                                      final double pointWidth = 24.0;
                                      final double minWidth = MediaQuery.of(context).size.width - 120;
                                      final double dataWidth = _wurfe.length * pointWidth;
                                      final double chartWidth = dataWidth < minWidth ? minWidth : dataWidth;
                                      
                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Container(
                                          width: chartWidth,
                                          padding: const EdgeInsets.only(right: 12, top: 8),
                                          child: LineChart(
                                            LineChartData(
                                              gridData: FlGridData(
                                                show: true,
                                                drawVerticalLine: true,
                                                getDrawingHorizontalLine: (value) {
                                                  return FlLine(
                                                    color: AppColors.border.withOpacity(0.3),
                                                    strokeWidth: 0.8,
                                                    dashArray: [5, 5],
                                                  );
                                                },
                                                getDrawingVerticalLine: (value) {
                                                  return FlLine(
                                                    color: AppColors.border.withOpacity(0.2),
                                                    strokeWidth: 0.8,
                                                    dashArray: [5, 5],
                                                  );
                                                },
                                              ),
                                              titlesData: FlTitlesData(
                                                show: true,
                                                rightTitles: const AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false),
                                                ),
                                                topTitles: const AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false),
                                                ),
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 32,
                                                    getTitlesWidget: (value, meta) {
                                                      if (!value.isFinite) {
                                                        return const SizedBox.shrink();
                                                      }
                                                      // Show every few labels based on data size
                                                      final interval = _getXAxisIntervalForScroll();
                                                      if (value % interval != 0 && value != 0) {
                                                        return const SizedBox.shrink();
                                                      }
                                                      return Padding(
                                                        padding: const EdgeInsets.only(top: 10.0),
                                                        child: Text(
                                                          (value + 1).toInt().toString(),
                                                          style: AppFont.caption.copyWith(
                                                            fontSize: 11,
                                                            color: AppColors.textMuted,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                leftTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 48,
                                                    getTitlesWidget: (value, meta) {
                                                      if (!value.isFinite) {
                                                        return const SizedBox.shrink();
                                                      }
                                                      return Padding(
                                                        padding: const EdgeInsets.only(right: 8),
                                                        child: Text(
                                                          value.toStringAsFixed(1),
                                                          style: AppFont.caption.copyWith(
                                                            fontSize: 11,
                                                            color: AppColors.textMuted,
                                                          ),
                                                          textAlign: TextAlign.right,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              borderData: FlBorderData(
                                                show: false,
                                              ),
                                              minX: 0,
                                              maxX: maxX,
                                              minY: minY,
                                              maxY: maxY,
                                              lineTouchData: LineTouchData(
                                                enabled: true,
                                                touchTooltipData: LineTouchTooltipData(
                                                  fitInsideHorizontally: true,
                                                  fitInsideVertically: true,
                                                  tooltipMargin: 8,
                                                  getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.9),
                                                  tooltipRoundedRadius: 8,
                                                  tooltipPadding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  getTooltipItems: (touchedSpots) {
                                                    return touchedSpots.map((spot) {
                                                      return LineTooltipItem(
                                                        'Throw ${(spot.x + 1).toInt()}\n${spot.y.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}',
                                                        const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      );
                                                    }).toList();
                                                  },
                                                ),
                                              ),
                                              lineBarsData: [
                                                LineChartBarData(
                                                  spots: spots,
                                                  isCurved: false,
                                                  color: AppColors.primary,
                                                  barWidth: 2.5,
                                                  isStrokeCapRound: false,
                                                  dotData: FlDotData(
                                                    show: true,
                                                    getDotPainter: (spot, percent, barData, index) {
                                                      return FlDotCirclePainter(
                                                        radius: 3.5,
                                                        color: AppColors.primary,
                                                        strokeWidth: 1.5,
                                                        strokeColor: AppColors.surface,
                                                      );
                                                    },
                                                  ),
                                                  belowBarData: BarAreaData(
                                                    show: false,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Stats Summary
                        Card(
                          elevation: 3,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatRow(
                                  Icons.confirmation_number_outlined,
                                  'Number of throws',
                                  _wurfe.length.toString(),
                                  '',
                                ),
                                const SizedBox(height: 12),
                                Divider(color: AppColors.border.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                _buildStatRow(
                                  Icons.trending_up,
                                  'Average',
                                  _getAverageValue().toStringAsFixed(2),
                                  _getMetricUnit(_selectedMetric),
                                ),
                                const SizedBox(height: 12),
                                Divider(color: AppColors.border.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                _buildStatRow(
                                  Icons.arrow_upward,
                                  'Maximum',
                                  _getMaxValue().toStringAsFixed(2),
                                  _getMetricUnit(_selectedMetric),
                                ),
                                const SizedBox(height: 12),
                                Divider(color: AppColors.border.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                _buildStatRow(
                                  Icons.arrow_downward,
                                  'Minimum',
                                  _getMinValue().toStringAsFixed(2),
                                  _getMetricUnit(_selectedMetric),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMetricUnit(YAxisMetric metric) {
    switch (metric) {
      case YAxisMetric.rotation:
        return 'rps';
      case YAxisMetric.height:
        return 'm';
      case YAxisMetric.acceleration:
        return 'm/s²';
    }
  }

  Widget _buildStatRow(IconData icon, String label, String value, String unit) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppFont.body.copyWith(fontSize: 15),
          ),
        ),
        Text(
          value,
          style: AppFont.statValue.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (unit.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              unit,
              style: AppFont.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  double _getXAxisIntervalForScroll() {
    // For horizontal scroll, show every 5th throw for clean spacing
    final length = _wurfe.length;
    if (length <= 1) return 1.0;
    if (length <= 10) return 2.0;
    if (length <= 30) return 5.0;
    return 10.0;
  }

  double _getMaxX() {
    if (_wurfe.isEmpty) return 1.0;
    return (_wurfe.length - 1).toDouble();
  }

  // Calculate Y-axis range (min and max) in one pass to avoid inconsistencies
  Map<String, double> _getYAxisRange() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    
    if (values.isEmpty) {
      return {'min': 0.0, 'max': 10.0};
    }
    
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    
    // If all values are the same, add padding
    if (max == min) {
      final padding = max == 0 ? 1.0 : max * 0.2;
      return {
        'min': (max > 0 ? max * 0.8 : 0.0),
        'max': max + padding,
      };
    }
    
    // Add 15% padding for better visualization
    final range = max - min;
    final minY = (min - range * 0.15).clamp(0.0, double.infinity);
    final maxY = max + range * 0.15;
    
    // Final safety check: ensure minY < maxY
    if (minY >= maxY) {
      return {
        'min': 0.0,
        'max': (max > 0 ? max * 1.2 : 10.0),
      };
    }
    
    return {'min': minY, 'max': maxY};
  }

  double _getMinY() {
    return _getYAxisRange()['min']!;
  }

  double _getMaxY() {
    return _getYAxisRange()['max']!;
  }

  double _getAverageValue() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _getMaxValue() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double _getMinValue() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a < b ? a : b);
  }
}
