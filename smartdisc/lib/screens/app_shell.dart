import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'analysis_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'discs_screen.dart';
import '../services/auth_service.dart';
import '../services/disc_service.dart';

class AppShell extends StatefulWidget {
  /// initialIndex selects which tab to show
  /// 0 = dashboard, 1 = analysis, 2 = history, 3 = discs, 4 = profile
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;
  late final List<Widget> _pages;
  final List<String> _titles = ['Dashboard', 'Analysis', 'History', 'Discs', 'Profile'];

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
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              final auth = AuthService();
              await auth.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/auth');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ];
      case 3: // Discs - Add button
        return [
          Builder(
            builder: (context) => IconButton(
              onPressed: () async {
                final ctrl = TextEditingController();
                final name = await showDialog<String?>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Add Disc'),
                    content: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: 'Disc name'),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty) {
                  final svc = DiscService.instance();
                  await svc.init();
                  await svc.add(name);
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analysis'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.storage_rounded), label: 'Discs'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
