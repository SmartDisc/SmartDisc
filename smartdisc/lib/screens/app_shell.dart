import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'analysis_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'discs_screen.dart';
import 'ble_test_screen.dart';
import 'disc_assignments_screen.dart';
import '../services/auth_service.dart';
import '../services/disc_service.dart';
import '../utils/responsive.dart';

class AppShell extends StatefulWidget {
  /// initialIndex selects which tab to show
  /// 0 = dashboard, 1 = analysis, 2 = history, 3 = discs, 4 = BLE, 5 = profile
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;
  late final List<Widget> _pages;
  late final List<String> _titles;
  late final List<BottomNavigationBarItem> _navItems;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<AnalysisScreenState> _analysisKey = GlobalKey<AnalysisScreenState>();
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final auth = AuthService();
    final role = await auth.currentUserRole();
    setState(() {
      _userRole = role;
      _initializePages();
    });
  }

  void _initializePages() {
    final isTrainer = _userRole == 'trainer';
    
    if (isTrainer) {
      _titles = [
        'Dashboard',
        'Analysis',
        'History',
        'Discs',
        'Assignments',
        'BLE Connect',
        'Profile',
      ];
      _pages = [
        DashboardScreen(key: _dashboardKey),
        AnalysisScreen(key: _analysisKey),
        const HistoryScreen(),
        const DiscsScreen(),
        const DiscAssignmentsScreen(),
        const BleTestScreen(),
        const ProfileScreen(),
      ];
      _navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Analysis',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.storage_rounded),
          label: 'Discs',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Assignments',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bluetooth),
          label: 'BLE',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    } else {
      _titles = [
        'Dashboard',
        'Analysis',
        'History',
        'Discs',
        'BLE Connect',
        'Profile',
      ];
      _pages = [
        DashboardScreen(key: _dashboardKey),
        AnalysisScreen(key: _analysisKey),
        const HistoryScreen(),
        const DiscsScreen(),
        const BleTestScreen(),
        const ProfileScreen(),
      ];
      _navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Analysis',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.storage_rounded),
          label: 'Discs',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bluetooth),
          label: 'BLE',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    }
  }

  void _onItemTapped(int idx) {
    if (idx != _selectedIndex) {
      setState(() {
        _selectedIndex = idx;
      });
    }
  }

  List<Widget>? _getAppBarActions() {
    switch (_selectedIndex) {
      case 1: // Analysis - Export
        return [
          IconButton(
            onPressed: () {
              final state = _analysisKey.currentState;
              if (state == null) return;
              state.openExportSheet();
            },
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export',
          ),
        ];
      case 3: // Discs - Add button
        return [
          Builder(
            builder: (context) => IconButton(
              onPressed: () async {
                final idCtrl = TextEditingController();
                final nameCtrl = TextEditingController();
                try {
                  final result = await showDialog<Map<String, String>?>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add Disc'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: idCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Disc ID (e.g., DISC-01)',
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name (optional)',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop({
                            'id': idCtrl.text.trim(),
                            'name': nameCtrl.text.trim(),
                          }),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                  if (result != null && result['id']!.isNotEmpty) {
                    // Normalize: trim and convert to uppercase
                    final normalizedId = result['id']!.trim().toUpperCase();
                    final name = result['name']!.trim().isEmpty 
                        ? null 
                        : result['name']!.trim();
                    
                    // Validate with regex: ^[A-Z0-9\-]{3,32}$
                    final idRegex = RegExp(r'^[A-Z0-9\-]{3,32}$');
                    if (!idRegex.hasMatch(normalizedId)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid disc ID. Use 3-32 characters (A-Z, 0-9, hyphens only)',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    
                    final svc = DiscService.instance();
                    await svc.init();
                    
                    // Note: Players only see assigned discs, so we can't check duplicates client-side.
                    // The backend will handle duplicate validation with proper error messages.
                    
                    try {
                      await svc.add(
                        normalizedId,
                        name: name ?? normalizedId,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Disc added successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        // Extract user-friendly error message
                        final errorStr = e.toString().toLowerCase();
                        String message;
                        
                        if (errorStr.contains('duplicate_key') || 
                            errorStr.contains('already exists') ||
                            errorStr.contains('unique constraint') ||
                            errorStr.contains('integrity constraint')) {
                          message = 'Disc ID "$normalizedId" already exists. Choose a different ID.';
                        } else {
                          message = 'Failed to add disc. Please try again.';
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      }
                    }
                  }
                } finally {
                  // Always dispose controllers after dialog closes
                  idCtrl.dispose();
                  nameCtrl.dispose();
                }
              },
              icon: const Icon(Icons.add),
              tooltip: 'Add disc',
            ),
          ),
        ];
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final responsive = context.responsive;
    final isMobile = responsive.isMobile;

    if (isMobile) {
      // Mobile: Bottom Navigation
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_titles[_selectedIndex]),
          actions: _getAppBarActions(),
        ),
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: _navItems,
        ),
      );
    } else {
      // Tablet/Desktop: Navigation Rail
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_titles[_selectedIndex]),
          actions: _getAppBarActions(),
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              extended: responsive.isLargeDesktop,
              destinations: _navItems.map((item) {
                return NavigationRailDestination(
                  icon: item.icon,
                  selectedIcon: item.activeIcon ?? item.icon,
                  label: Text(item.label ?? ''),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _pages),
            ),
          ],
        ),
      );
    }
  }
}
