import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/role_selection_screen.dart';
import 'screens/throw_list_example.dart';
import 'services/auth_service.dart';
import 'styles/app.theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('de_AT');
  } catch (_) {
    // Ignore; fallback formatting will still work without locale data.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartDisc',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routes: {
        '/role': (context) => const RoleSelectionScreen(),
        '/auth': (context) => const _AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const AppShell(initialIndex: 0),
        '/analysis': (context) => const AppShell(initialIndex: 1),
        '/history': (context) => const AppShell(initialIndex: 2),
        '/discs': (context) => const AppShell(initialIndex: 3),
        '/profile': (context) => const AppShell(initialIndex: 4),
        '/throws': (context) => const ThrowListExample(),
      },
      home: const RoleSelectionScreen(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final AuthService _auth = AuthService();
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final bool ok = await _auth.isLoggedIn();
    if (mounted) {
      setState(() {
        _loggedIn = ok;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _loggedIn ? const AppShell() : const LoginScreen();
  }
}
