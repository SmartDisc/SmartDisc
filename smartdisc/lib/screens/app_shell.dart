import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'analysis_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'discs_screen.dart';
import 'ble_test_screen.dart';
import '../services/auth_service.dart';
import '../services/disc_service.dart';

class AppShell extends StatefulWidget {
  /// initialIndex selects which tab to show
  /// 0 = dashboard, 1 = analysis, 2 = history, 3 = discs, 4 = profile, 5 = BLE
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;
  late final List<Widget> _pages;
  final List<String> _titles = [
    'Dashboard',
    'Analysis',
    'History',
    'Discs',
    'Profile',
    'BLE Connect',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = [
      const DashboardScreen(),
      const AnalysisScreen(),
      const HistoryScreen(),
      const DiscsScreen(),
      const ProfileScreen(),
      const BleTestScreen(),
    ];
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
      case 0: // Dashboard - Logout button
        return [
          TextButton.icon(
            onPressed: () async {
              final auth = AuthService();
              await auth.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/auth');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
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
                    
                    // Check for duplicates before creating
                    final existingDiscs = svc.discs.value;
                    final duplicateExists = existingDiscs.any(
                      (disc) => (disc['id'] as String?)?.toUpperCase() == normalizedId,
                    );
                    
                    if (duplicateExists) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Disc ID "$normalizedId" already exists'),
                          ),
                        );
                      }
                      return;
                    }
                    
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add disc: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: _getAppBarActions(),
      ),
      // The body contains the pages as full Scaffolds so each can keep its own AppBar/FAB
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
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
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'BLE',
          ),
        ],
      ),
    );
  }
}
