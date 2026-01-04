import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/auth_start_screen.dart';
import 'screens/register_screen.dart';
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
        '/auth': (context) => const AuthStartScreen(),
        '/auth/login': (context) => const LoginScreen(),
        '/auth/register': (context) => const RegisterScreen(),
        '/player/dashboard': (context) => const AppShell(initialIndex: 0),
        '/trainer/dashboard': (context) => const AppShell(initialIndex: 0),
        '/dashboard': (context) => const _RoleBasedDashboard(),
        '/analysis': (context) => const AppShell(initialIndex: 1),
        '/history': (context) => const AppShell(initialIndex: 2),
        '/discs': (context) => const AppShell(initialIndex: 3),
        '/profile': (context) => const AppShell(initialIndex: 4),
        '/throws': (context) => const ThrowListExample(),
      },
      home: const _AuthGate(),
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

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final bool hasToken = await _auth.isLoggedIn();
    if (!mounted) return;
    
    if (!hasToken) {
      Navigator.of(context).pushReplacementNamed('/auth');
      return;
    }
    
    // Token vorhanden: User-Daten vom Server abrufen
    final userData = await _auth.me();
    if (!mounted) return;
    
    if (userData == null) {
      // Token ungültig, ausloggen
      await _auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/auth');
      return;
    }
    
    // Role-basiertes Routing
    final role = userData['role'] as String?;
    if (role == 'player') {
      Navigator.of(context).pushReplacementNamed('/player/dashboard');
    } else if (role == 'trainer') {
      Navigator.of(context).pushReplacementNamed('/trainer/dashboard');
    } else {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RoleBasedDashboard extends StatelessWidget {
  const _RoleBasedDashboard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService().currentUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = snapshot.data;
        if (role == 'player') {
          return const AppShell(initialIndex: 0);
        } else if (role == 'trainer') {
          return const AppShell(initialIndex: 0);
        } else {
          return const AuthStartScreen();
        }
      },
    );
  }
}

Future<void> someMethod(BuildContext context) async {
  if (!context.mounted) return;
  Navigator.pushReplacementNamed(context, '/dashboard');
}
