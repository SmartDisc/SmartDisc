import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

class RoleSelectionScreen extends StatelessWidget {
  RoleSelectionScreen({super.key});

  final AuthService _auth = AuthService();

  Future<void> _navigateToAuth(BuildContext context, String role) async {
    await _auth.saveRole(role);
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width > 420 ? (size.width - 420) / 2 + 24 : 24,
            vertical: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
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
              const SizedBox(height: 24),
              const SizedBox(height: 8),
              Text(
                'Who are you?',
                style: AppFont.headline,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToAuth(context, 'player'),
                  child: const Text('I am a Player'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToAuth(context, 'trainer'),
                  child: const Text('I am a Trainer'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

