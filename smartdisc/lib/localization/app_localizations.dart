import 'package:flutter/material.dart';

/// Supported app languages.
enum AppLanguage { en, de }

/// Inherited widget that stores the current language and a setter.
class AppLanguageScope extends InheritedWidget {
  final AppLanguage language;
  final void Function(AppLanguage) setLanguage;

  const AppLanguageScope({
    super.key,
    required this.language,
    required this.setLanguage,
    required Widget child,
  }) : super(child: child);

  static AppLanguageScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant AppLanguageScope oldWidget) =>
      oldWidget.language != language;
}

/// Simple string provider for EN / DE.
class AppStrings {
  final AppLanguage language;
  const AppStrings(this.language);

  bool get _isDe => language == AppLanguage.de;

  String get appTitle => 'SmartDisc';

  // Auth start
  String get authWelcomeTagline => _isDe
      ? 'Analysiere deine Würfe. Verbessere dein Spiel.'
      : 'Track your throws. Improve your game.';
  String get authLoginButton => _isDe ? 'Anmelden' : 'Log in';
  String get authCreateAccountButton => _isDe ? 'Konto erstellen' : 'Create account';

  // Login
  String get loginTitle => _isDe ? 'Anmelden' : 'Log in';
  String get loginWelcome => _isDe ? 'Willkommen zurück' : 'Welcome back';
  String get loginSubtitle =>
      _isDe ? 'Melde dich bei SmartDisc an' : 'Sign in to continue to SmartDisc';
  String get loginEmailHint =>
      _isDe ? 'email@beispiel.com' : 'email@example.com';
  String get loginPasswordHint => _isDe ? 'Passwort' : 'Password';
  String get loginContinueButton => _isDe ? 'Weiter' : 'Continue';
  String get loginCreateAccountCta =>
      _isDe ? 'Noch kein Konto? Registrieren' : 'Create Account';
  String get validationEmailRequired =>
      _isDe ? 'Bitte E-Mail-Adresse eingeben' : 'Please enter an email address';
  String get validationEmailInvalid =>
      _isDe ? 'Ungültige E-Mail-Adresse' : 'Invalid email address';
  String get validationPasswordRequired =>
      _isDe ? 'Bitte Passwort eingeben' : 'Please enter a password';
  String get validationPasswordTooShort =>
      _isDe ? 'Mindestens 6 Zeichen' : 'At least 6 characters';

  // Register
  String get registerTitle => _isDe ? 'Registrieren' : 'Register';
  String get registerFirstNameLabel =>
      _isDe ? 'Vorname' : 'First name';
  String get registerLastNameLabel =>
      _isDe ? 'Nachname' : 'Last name';
  String get registerEmailLabel => _isDe ? 'E-Mail' : 'Email';
  String get registerPasswordLabel => _isDe ? 'Passwort' : 'Password';
  String get registerPasswordConfirmLabel =>
      _isDe ? 'Passwort bestätigen' : 'Confirm password';
  String get registerRoleLabel => _isDe ? 'Rolle' : 'Role';
  String get registerPlayerOption => _isDe ? 'Spieler*in' : 'Player';
  String get registerTrainerOption => _isDe ? 'Trainer*in' : 'Coach';
  String get registerPrimaryButton => _isDe ? 'Registrieren' : 'Register';

  // Navigation / labels
  String get navDashboard => _isDe ? 'Dashboard' : 'Dashboard';
  String get navAnalysis => _isDe ? 'Analyse' : 'Analysis';
  String get navHistory => _isDe ? 'Verlauf' : 'History';
  String get navDiscs => _isDe ? 'Scheiben' : 'Discs';
  String get navBle => _isDe ? 'BLE' : 'BLE';
  String get navProfile => _isDe ? 'Profil' : 'Profile';

  // Profile
  String get profileAccountDetails =>
      _isDe ? 'Kontodetails' : 'Account details';
  String get profileEmailLabel => _isDe ? 'E-Mail' : 'Email';
  String get profileRoleLabel => _isDe ? 'Rolle' : 'Role';
  String get profileLogout => _isDe ? 'Abmelden' : 'Log out';
  String get profileLanguageTitle =>
      _isDe ? 'Sprache' : 'Language';
  String get profileLanguageSubtitle =>
      _isDe ? 'App-Sprache auswählen' : 'Choose app language';
  String get languageEnglish => 'English';
  String get languageGerman => 'Deutsch';
}

extension AppStringsContext on BuildContext {
  AppStrings get strings =>
      AppStrings(AppLanguageScope.of(this).language);
}

