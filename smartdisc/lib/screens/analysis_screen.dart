import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../services/disc_service.dart';
import '../models/wurf.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

enum YAxisMetric {
  rotation, // Rotation
  height, // Höhe
  acceleration, // Maximum acceleration
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();
  final DiscService _discService = DiscService.instance();
  List<Wurf> _wurfe = [];
  List<Wurf> _allWurfe = []; // Store all wurfe for filtering
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
    // Listen for disc changes and reload data
    _discService.discs.addListener(_onDiscsChanged);
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
      final wurfe = await _apiService.getWuerfe(limit: 100);
      // Sort by timestamp (oldest first for graph)
      wurfe.sort((a, b) {
        final aTime = a.erstelltAm != null ? DateTime.parse(a.erstelltAm!) : DateTime(1970);
        final bTime = b.erstelltAm != null ? DateTime.parse(b.erstelltAm!) : DateTime(1970);
        return aTime.compareTo(bTime);
      });
      setState(() {
        _allWurfe = wurfe;
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

  DateTime? _getFirstThrowTime() {
    if (_allWurfe.isEmpty) return null;
    DateTime? firstTime;
    for (final wurf in _allWurfe) {
      if (wurf.erstelltAm != null) {
        final time = DateTime.parse(wurf.erstelltAm!);
        if (firstTime == null || time.isBefore(firstTime)) {
          firstTime = time;
        }
      }
    }
    return firstTime;
  }

  List<FlSpot> _getChartSpots() {
    if (_wurfe.isEmpty) return [];

    // Use the first throw time from ALL wurfe, not just filtered ones
    final firstTime = _getFirstThrowTime() ?? DateTime.now();

    // Group by integer hour (so each integer X has a single Y value).
    final Map<int, List<double>> grouped = {};
    for (final wurf in _wurfe) {
      if (wurf.erstelltAm != null) {
        final timestamp = DateTime.parse(wurf.erstelltAm!);
        final xInt = timestamp.difference(firstTime).inHours;
        final yValue = _getMetricValue(wurf, _selectedMetric);
        if (yValue != null) {
          grouped.putIfAbsent(xInt, () => []).add(yValue);
        }
      }
    }

    final spots = grouped.entries.map((e) {
      final x = e.key.toDouble();
      final values = e.value;
      final avg = values.reduce((a, b) => a + b) / values.length;
      return FlSpot(x, avg);
    }).toList();

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  String _formatXAxisLabel(double value) {
    // Show time in hours, or days if > 24h
    if (value >= 24) {
      final days = (value / 24).round();
      return '${days}d';
    }
    return '${value.round()}h';
  }

  List<Map<String, String>> _getAvailableDiscs() {
    // Get discs from DiscService (backend-managed) - these are the source of truth
    final discMap = <String, String>{}; // id -> display name
    
    // First, add all discs from backend
    for (final disc in _discService.discs.value) {
      final id = (disc['id'] as String?) ?? '';
      if (id.isNotEmpty) {
        discMap[id] = (disc['name'] as String?) ?? id;
      }
    }
    
    // Also include any disc IDs from throws (in case there's data for a disc that's been deleted)
    for (final wurf in _allWurfe) {
      if (wurf.scheibeId != null && wurf.scheibeId!.isNotEmpty) {
        if (!discMap.containsKey(wurf.scheibeId)) {
          discMap[wurf.scheibeId!] = wurf.scheibeId!;
        }
      }
    }
    
    // Convert to list of maps for easier handling
    return discMap.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => (a['id'] ?? '').compareTo(b['id'] ?? ''));
  }

  void _applyDiscFilter() {
    if (_selectedDisc == null) {
      // Show all
      _wurfe = List.from(_allWurfe);
    } else {
      // Filter by selected disc
      _wurfe = _allWurfe.where((w) => w.scheibeId == _selectedDisc).toList();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Disc and Metric Dropdowns in body instead of AppBar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _selectedDisc,
                      hint: const Text('Disc', style: AppFont.body),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All', style: AppFont.body),
                        ),
                        ..._getAvailableDiscs().map((discInfo) {
                          final discId = discInfo['id'] ?? '';
                          final discName = discInfo['name'] ?? discId;
                          return DropdownMenuItem<String?>(
                            value: discId,
                            child: Text(discName, style: AppFont.body),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<YAxisMetric>(
                      value: _selectedMetric,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      items: YAxisMetric.values.map((metric) {
                        return DropdownMenuItem<YAxisMetric>(
                          value: metric,
                          child: Text(
                            _getMetricDisplayName(metric),
                            style: AppFont.body,
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
                ],
              ),
            ),
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
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            height: 400,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trend over Time',
                                  style: AppFont.subheadline,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'X-Axis: Time (since first throw) • Y-Axis: ${_getMetricLabel(_selectedMetric)}',
                                  style: AppFont.caption,
                                ),
                                const SizedBox(height: 16),
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
                                      return LineChart(
                                        LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: _getYAxisInterval(),
                                        getDrawingHorizontalLine: (value) {
                                          return FlLine(
                                            color: AppColors.border,
                                            strokeWidth: 1,
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
                                            reservedSize: 30,
                                            interval: _getXAxisInterval(),
                                            getTitlesWidget: (value, meta) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  _formatXAxisLabel(value),
                                                  style: AppFont.caption,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 50,
                                            interval: _getYAxisInterval(),
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                value.toStringAsFixed(1),
                                                style: AppFont.caption,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                          color: AppColors.border,
                                          width: 1,
                                        ),
                                      ),
                                      minX: 0,
                                      maxX: _getMaxX().clamp(0.0, double.infinity),
                                      minY: _getMinY(),
                                      maxY: _getMaxY(),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: spots,
                                          isCurved: true,
                                          color: AppColors.primary,
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter: (spot, percent, barData, index) {
                                              return FlDotCirclePainter(
                                                radius: 4,
                                                color: AppColors.primary,
                                                strokeWidth: 2,
                                                strokeColor: AppColors.surface,
                                              );
                                            },
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: AppColors.primary.withAlpha(26),
                                          ),
                                        ),
                                      ],
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
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statistics',
                                  style: AppFont.subheadline,
                                ),
                                const SizedBox(height: 12),
                                _buildStatRow(
                                  'Number of throws',
                                  _wurfe.length.toString(),
                                ),
                                const Divider(),
                                _buildStatRow(
                                  'Average ${_getMetricDisplayName(_selectedMetric)}',
                                  _getAverageValue().toStringAsFixed(2),
                                ),
                                const Divider(),
                                _buildStatRow(
                                  'Max ${_getMetricDisplayName(_selectedMetric)}',
                                  _getMaxValue().toStringAsFixed(2),
                                ),
                                const Divider(),
                                _buildStatRow(
                                  'Min ${_getMetricDisplayName(_selectedMetric)}',
                                  _getMinValue().toStringAsFixed(2),
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
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppFont.body),
        Text(value, style: AppFont.statValue),
      ],
    );
  }

  double _getYAxisInterval() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 1.0;
    final range = values.reduce((a, b) => a > b ? a : b) -
        values.reduce((a, b) => a < b ? a : b);
    if (range == 0) return 1.0;
    return (range / 5).ceilToDouble();
  }

  double _getXAxisInterval() {
    // Always show in 1-day steps (24 hours)
    return 24.0;
  }

  double _getMaxX() {
    if (_wurfe.isEmpty) return 1.0;
    
    // Use first time from all wurfe for consistent scaling
    final firstTime = _getFirstThrowTime() ?? DateTime.now();
    
    // Find the latest time from filtered wurfe
    DateTime? lastTime;
    for (final wurf in _wurfe) {
      if (wurf.erstelltAm != null) {
        final time = DateTime.parse(wurf.erstelltAm!);
        if (lastTime == null || time.isAfter(lastTime)) {
          lastTime = time;
        }
      }
    }
    
    if (lastTime == null) return 1.0;
    final diff = lastTime.difference(firstTime).inHours.toDouble();
    return diff > 0 ? diff : 1.0;
  }

  double _getMinY() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0.0;
    final min = values.reduce((a, b) => a < b ? a : b);
    final minValue = (min * 0.9).clamp(0.0, double.infinity);
    // Ensure minY is always less than maxY
    final maxValue = _getMaxY();
    if (minValue >= maxValue) {
      return maxValue > 0 ? maxValue * 0.9 : 0.0;
    }
    return minValue;
  }

  double _getMaxY() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 10.0;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    // If all values are the same, add padding to prevent minY == maxY
    if (max == min) {
      return max + (max == 0 ? 1.0 : max * 0.2);
    }
    return (max * 1.1).clamp(0.0, double.infinity);
  }

  double _getAverageValue() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _getMaxValue() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double _getMinValue() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a < b ? a : b);
  }
}
