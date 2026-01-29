import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Formular-Validierung
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Eingabefelder-Controller
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Services
  final AuthService _auth = AuthService();
  
  // State-Variablen
  bool _isSubmitting = false;  // Zeigt an, ob Login-Prozess läuft
  String? _errorMessage;       // Fehlermeldung (null = kein Fehler)

  @override
  void dispose() {
    // Controller aufräumen (verhindert Memory Leaks)
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================
  // VALIDIERUNG
  // ============================================

  /// Validiert E-Mail-Eingabe
  /// Gibt null zurück wenn gültig, sonst Fehlermeldung
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bitte E-Mail eingeben';
    }
    if (!value.contains('@')) {
      return 'Ungültige E-Mail';
    }
    return null;  // Gültig
  }

  /// Validiert Passwort-Eingabe
  /// Gibt null zurück wenn gültig, sonst Fehlermeldung
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Bitte Passwort eingeben';
    }
    if (value.length < 6) {
      return 'Mindestens 6 Zeichen';
    }
    return null;  // Gültig
  }

  // ============================================
  // LOGIN-LOGIK
  // ============================================

  /// Führt Login-Prozess aus
  /// 1. Validiert Formular
  /// 2. Ruft API auf
  /// 3. Navigiert basierend auf Rolle
  Future<void> _submit() async {
    // Formular-Validierung
    if (!_formKey.currentState!.validate()) {
      return;  // Stoppt wenn Validierung fehlschlägt
    }

    // Loading-State aktivieren
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;  // Alte Fehler löschen
    });

    try {
      // API-Aufruf: Login
      await _auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Navigation nach erfolgreichem Login
      await _navigateAfterLogin();
    } catch (e) {
      // Fehlerbehandlung
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      // Loading-State deaktivieren
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Navigiert nach Login basierend auf Benutzer-Rolle
  /// Player → /player/dashboard
  /// Coach → /coach/dashboard
  Future<void> _navigateAfterLogin() async {
    final role = await _auth.currentUserRole();
    if (!mounted) return;

    if (role == 'player') {
      Navigator.of(context).pushReplacementNamed('/player/dashboard');
    } else if (role == 'coach') {
      Navigator.of(context).pushReplacementNamed('/coach/dashboard');
    } else {
      // Fallback: Zurück zum Auth-Screen
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  // ============================================
  // UI-WIDGETS
  // ============================================

  /// E-Mail-Eingabefeld
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(hintText: 'email@domain.com'),
      validator: _validateEmail,
    );
  }

  /// Passwort-Eingabefeld (versteckt)
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(hintText: 'Passwort'),
      obscureText: true,  // Passwort wird versteckt
      validator: _validatePassword,
    );
  }

  /// Fehler-Banner (nur sichtbar wenn Fehler vorhanden)
  Widget _buildErrorBanner() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();  // Kein Fehler = unsichtbar
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Haupt-Login-Button
  /// Zeigt Loading-Indikator während Login-Prozess
  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,  // Deaktiviert während Login
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Continue'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,  // Kein Zurück-Pfeil
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  /// Haupt-Body des Login-Screens
  Widget _buildBody() {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: _buildLoginForm(),
        ),
      ),
    );
  }

  /// Login-Formular mit allen Eingabefeldern und Buttons
  Widget _buildLoginForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo/Header
            const _Header(),
            const SizedBox(height: 32),
            
            // Titel
            Text('Login', style: AppFont.headline),
            const SizedBox(height: 28),
            
            // Eingabefelder
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 16),
            
            // Fehlermeldung (falls vorhanden)
            _buildErrorBanner(),
            const SizedBox(height: 24),
            
            // Login-Button
            _buildPrimaryButton(),
            const SizedBox(height: 20),
            
            // Trennlinie "oder"
            const _OrDivider(),
            const SizedBox(height: 20),
            
            // Registrierungs-Button
            _buildRegisterButton(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// Button zum Navigieren zur Registrierung
  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.pushNamed(context, '/auth/register'),
        child: const Text('Create Account'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 220,
          height: 220,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/smart_disc_logo.jpg',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: AppColors.border)),
        SizedBox(width: 12),
        Text('or', style: AppFont.caption),
        SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
