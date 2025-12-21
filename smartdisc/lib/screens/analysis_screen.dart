import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/wurf.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

enum YAxisMetric {
  distance, // Entfernung (disc/time initially)
  rotation, // Rotation
  height, // Höhe
  speed, // Geschwindigkeit
  timestamp, // DISC7TIME - when played
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();
  List<Wurf> _wurfe = [];
  List<Wurf> _allWurfe = []; // Store all wurfe for filtering
  bool _isLoading = true;
  YAxisMetric _selectedMetric = YAxisMetric.distance;
  String? _selectedDisc; // null = "Alle"

  @override
  void initState() {
    super.initState();
    _loadWurfe();
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
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  String _getMetricLabel(YAxisMetric metric) {
    switch (metric) {
      case YAxisMetric.distance:
        return 'Entfernung (m)';
      case YAxisMetric.rotation:
        return 'Rotation (rps)';
      case YAxisMetric.height:
        return 'Höhe (m)';
      case YAxisMetric.speed:
        return 'Geschwindigkeit (m/s)';
      case YAxisMetric.timestamp:
        return 'Zeit seit erstem Wurf (h)';
    }
  }

  String _getMetricDisplayName(YAxisMetric metric) {
    switch (metric) {
      case YAxisMetric.distance:
        return 'Entfernung';
      case YAxisMetric.rotation:
        return 'Rotation';
      case YAxisMetric.height:
        return 'Höhe';
      case YAxisMetric.speed:
        return 'Geschwindigkeit';
      case YAxisMetric.timestamp:
        return 'DISC7TIME';
    }
  }

  double? _getMetricValue(Wurf wurf, YAxisMetric metric) {
    switch (metric) {
      case YAxisMetric.distance:
        return wurf.entfernung;
      case YAxisMetric.rotation:
        return wurf.rotation;
      case YAxisMetric.height:
        return wurf.hoehe;
      case YAxisMetric.speed:
        return wurf.geschwindigkeit;
      case YAxisMetric.timestamp:
        // For timestamp, show hours since first throw (or absolute hours if no first throw)
        if (_wurfe.isEmpty) return null;
        final firstTime = _wurfe.first.erstelltAm != null
            ? DateTime.parse(_wurfe.first.erstelltAm!)
            : DateTime.now();
        if (wurf.erstelltAm != null) {
          final throwTime = DateTime.parse(wurf.erstelltAm!);
          return throwTime.difference(firstTime).inHours.toDouble();
        }
        return null;
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

    final spots = <FlSpot>[];
    for (int i = 0; i < _wurfe.length; i++) {
      final wurf = _wurfe[i];
      final timestamp = wurf.erstelltAm != null
          ? DateTime.parse(wurf.erstelltAm!)
          : DateTime.now();

      // X-axis: time difference in hours from first throw (of all data)
      final x = timestamp.difference(firstTime).inHours.toDouble();

      // Y-axis: selected metric value
      final yValue = _getMetricValue(wurf, _selectedMetric);
      if (yValue != null) {
        spots.add(FlSpot(x, yValue));
      }
    }

    return spots;
  }

  String _formatXAxisLabel(double value) {
    // Show time in days: 1t, 2t, 3t, etc.
    // Round to nearest day, but show at least 0t if value is >= 0
    final days = (value / 24).round();
    return '${days >= 0 ? days : 0}t';
  }

  List<String> _getAvailableDiscs() {
    final discs = <String>{};
    for (final wurf in _allWurfe) {
      if (wurf.scheibeId != null && wurf.scheibeId!.isNotEmpty) {
        discs.add(wurf.scheibeId!);
      }
    }
    final sortedDiscs = discs.toList()..sort();
    return sortedDiscs;
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
      appBar: AppBar(
        title: const Text('Analysis', style: AppFont.headline),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // Disc Dropdown
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButton<String?>(
              value: _selectedDisc,
              hint: const Text('Disc', style: AppFont.body),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Alle', style: AppFont.body),
                ),
                ..._getAvailableDiscs().map((disc) {
                  return DropdownMenuItem<String?>(
                    value: disc,
                    child: Text(disc, style: AppFont.body),
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
          // Metric Dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
      body: _isLoading
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
                        'Keine Daten verfügbar',
                        style: AppFont.headline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Würfe werden hier angezeigt, sobald Daten vorhanden sind.',
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
                                  'Entwicklung über Zeit',
                                  style: AppFont.subheadline,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Y-Achse: ${_getMetricLabel(_selectedMetric)}',
                                  style: AppFont.caption,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: LineChart(
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
                                      maxX: _getMaxX(),
                                      minY: _getMinY(),
                                      maxY: _getMaxY(),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: _getChartSpots(),
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
                                            color: AppColors.primary.withOpacity(0.1),
                                          ),
                                        ),
                                      ],
                                    ),
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
                                  'Statistik',
                                  style: AppFont.subheadline,
                                ),
                                const SizedBox(height: 12),
                                _buildStatRow(
                                  'Anzahl Würfe',
                                  _wurfe.length.toString(),
                                ),
                                const Divider(),
                                _buildStatRow(
                                  'Durchschnitt ${_getMetricDisplayName(_selectedMetric)}',
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
    return (min * 0.9).clamp(0.0, double.infinity);
  }

  double _getMaxY() {
    final values = _wurfe
        .map((w) => _getMetricValue(w, _selectedMetric))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 10.0;
    final max = values.reduce((a, b) => a > b ? a : b);
    return max * 1.1;
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
