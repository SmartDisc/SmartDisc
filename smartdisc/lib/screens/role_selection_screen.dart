import 'package:flutter/material.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _navigateToAuth(BuildContext context, String role) {
    Navigator.pushReplacementNamed(
      context,
      '/auth',
      arguments: role,
    );
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
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.blueMuted, width: 2),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(24),
                child: Image.asset(
                  'assets/images/smart_disc_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              const Text('SMART DISC', style: AppFont.logoMark),
              const SizedBox(height: 8),
              Text(
                'Wer bist du?',
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
              const SizedBox(height: 24),
              Text(
                'Du kannst später im Profil wechseln.',
                style: AppFont.caption,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

