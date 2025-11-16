import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';
import '../widgets/stat_card.dart';
import '../models/wurf.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final api = ApiService();
  final AuthService _auth = AuthService();

  // Ten selectable discs
  final List<String> discs =
      List.generate(10, (i) => 'DISC-${(i + 1).toString().padLeft(2, '0')}');
  String selectedDisc = 'DISC-01';

  late Future<List<Wurf>> _wurfeF;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _wurfeF = api.getWuerfe(limit: 50, scheibeId: selectedDisc);
    setState(() {});
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  // Helpers: convert units if you like
  double _mpsToMph(num? v) => v == null ? 0 : v * 2.23693629;
  double _mToFt(num? m) => m == null ? 0 : m * 3.2808399;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartDisc'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _reload,
        icon: const Icon(Icons.sync),
        label: const Text('Reload'),
      ),
      body: FutureBuilder<List<Wurf>>(
        future: _wurfeF,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = s.data ?? [];

          // Responsive horizontal padding so narrow phones don't look cramped
          final screenW = MediaQuery.of(context).size.width;
          final horizontalPadding = screenW < 380 ? 12.0 : 16.0;

          // Compute KPIs for the selected disc
          final last10 = items.take(10).toList();
          final avgSpeedMps = last10.isEmpty
              ? 0
              : last10
                      .map((w) => w.geschwindigkeit ?? 0)
                      .fold<double>(0, (a, b) => a + b) /
                  last10.length;
          final avgSpeedMph = _mpsToMph(avgSpeedMps);

          final maxDistM = items.fold<double>(
              0, (mx, w) => (w.entfernung ?? 0) > mx ? (w.entfernung ?? 0) : mx);
          final maxDistFt = _mToFt(maxDistM);

          // interpret geschwindigkeit as spin rate (rps) for demo
          final avgRps = last10.isEmpty
              ? 0
              : last10
                      .map((w) => w.geschwindigkeit ?? 0)
                      .fold<double>(0, (a, b) => a + b) /
                  last10.length;
          final avgRpm = avgRps * 60.0;

          final totalThrows = items.length;

          return ListView(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 100),
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

              // KPI grid — responsive columns and aspect ratio based on available width
              LayoutBuilder(builder: (ctx, constraints) {
                // final w = constraints.maxWidth; // unused with maxCrossAxisExtent grid
                // Use a max extent grid so each card gets a reasonable minimum width
                // which prevents the grid from forcing a very small card height.
                const maxExtent = 360.0;
                return GridView(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxExtent,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  children: [
                    StatCard(
                      icon: Icons.flash_on_rounded,
                      label: 'Avg Speed',
                      value: '${avgSpeedMph.toStringAsFixed(1)} mph',
                      sublabel: 'Last 10 throws',
                    ),
                    StatCard(
                      icon: Icons.place_rounded,
                      label: 'Max Distance',
                      value: '${maxDistFt.toStringAsFixed(0)} ft',
                      sublabel: 'Personal best',
                    ),
                    StatCard(
                      icon: Icons.refresh_rounded,
                      label: 'Avg Rotation',
                      value: '${avgRps.toStringAsFixed(2)} rps\n${avgRpm.toStringAsFixed(0)} rpm',
                      sublabel: 'Spin rate',
                    ),
                    StatCard(
                      icon: Icons.timelapse_rounded,
                      label: 'Total Throws',
                      value: '$totalThrows',
                      sublabel: 'All time',
                    ),
                  ],
                );
              }),

              const SizedBox(height: 24),
              Text('Latest throws', style: AppFont.headline),

              const SizedBox(height: 8),
              if (items.isEmpty)
                const ListTile(title: Text('No throws yet'))
              else
                ...items.take(10).map((w) => Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        isThreeLine: true,
                        title: Text(
                          'Disc: ${w.scheibeId ?? '-'} • v=${w.geschwindigkeit ?? '-'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'd=${w.entfernung ?? '-'} m   •   ${w.erstelltAm ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            w.id,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}
