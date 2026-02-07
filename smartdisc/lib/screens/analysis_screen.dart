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

    // Simply plot each throw as a point (index as X, value as Y)
    final spots = <FlSpot>[];
    for (int i = 0; i < _wurfe.length; i++) {
      final yValue = _getMetricValue(_wurfe[i], _selectedMetric);
      if (yValue != null) {
        spots.add(FlSpot(i.toDouble(), yValue));
      }
    }
    return spots;
  }

  String _formatXAxisLabel(double value) {
    // Show throw number (index)
    return 'T${(value + 1).toInt()}';
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
    final screenHeight = MediaQuery.of(context).size.height;
    final chartHeight = (screenHeight * 0.4).clamp(250.0, 400.0);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        title: const Text('Analysis', style: AppFont.headline),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Disc Filter
                Expanded(
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
                ),
                const SizedBox(width: 12),
                // Metric Filter
                Expanded(
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
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
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
                                      
                                      // Calculate chart width based on data points
                                      // Show max 30 throws in viewport, ~24px per throw
                                      final double pointWidth = 24.0;
                                      final double minVisiblePoints = 30.0;
                                      final double chartWidth = (_wurfe.length * pointWidth).clamp(
                                        MediaQuery.of(context).size.width - 120, // Min width (fill available space)
                                        _wurfe.length * pointWidth, // Max width (scrollable)
                                      );
                                      
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
                                                horizontalInterval: _getYAxisInterval(),
                                                verticalInterval: _getXAxisIntervalForScroll(),
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
                                                    interval: _getXAxisIntervalForScroll(),
                                                    getTitlesWidget: (value, meta) {
                                                      // Show labels at intervals
                                                      if (value % _getXAxisIntervalForScroll() != 0) {
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
                                                    interval: _getYAxisInterval(),
                                                    getTitlesWidget: (value, meta) {
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
                                              maxX: _getMaxX().clamp(0.0, double.infinity),
                                              minY: _getMinY(),
                                              maxY: _getMaxY(),
                                              lineTouchData: LineTouchData(
                                                enabled: true,
                                                touchTooltipData: LineTouchTooltipData(
                                                  getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.9),
                                                  tooltipRoundedRadius: 8,
                                                  tooltipPadding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  getTooltipItems: (touchedSpots) {
                                                    return touchedSpots.map((spot) {
                                                      return LineTooltipItem(
                                                        'Throw ${(spot.x + 1).toInt()}\\n${spot.y.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}',
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

  double _getYAxisInterval() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 1.0;
    final range = values.reduce((a, b) => a > b ? a : b) -
        values.reduce((a, b) => a < b ? a : b);
    if (range == 0) return 1.0;
    
    // Calculate a nice interval (fewer grid lines for cleaner look)
    final rawInterval = range / 4; // 4 intervals instead of 5
    
    // Round to nice numbers
    if (rawInterval >= 10) {
      return (rawInterval / 10).ceil() * 10.0;
    } else if (rawInterval >= 1) {
      return rawInterval.ceil().toDouble();
    } else {
      return (rawInterval * 10).ceil() / 10;
    }
  }

  double _getXAxisInterval() {
    // Show fewer labels for less clutter
    if (_wurfe.length <= 5) return 1.0;
    if (_wurfe.length <= 10) return 2.0;
    if (_wurfe.length <= 20) return 5.0;
    if (_wurfe.length <= 50) return 10.0;
    return 20.0;
  }

  double _getXAxisIntervalForScroll() {
    // For horizontal scroll, show every 5th throw for clean spacing
    if (_wurfe.length <= 10) return 2.0;
    if (_wurfe.length <= 30) return 5.0;
    return 10.0;
  }

  double _getMaxX() {
    if (_wurfe.isEmpty) return 1.0;
    return (_wurfe.length - 1).toDouble();
  }

  double _getMinY() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0.0;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    
    // Add 15% padding below minimum for better visualization
    final range = max - min;
    if (range == 0) {
      return min > 0 ? min * 0.8 : 0.0;
    }
    
    final minValue = (min - range * 0.15).clamp(0.0, double.infinity);
    final maxValue = _getMaxY();
    
    // Ensure minY is always less than maxY
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
    
    // Add 15% padding above maximum for better visualization
    final range = max - min;
    return (max + range * 0.15).clamp(0.0, double.infinity);
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
