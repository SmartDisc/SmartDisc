import 'package:flutter/material.dart';
import '../styles/app_colors.dart';

class AuthStartScreen extends StatelessWidget {
  const AuthStartScreen({super.key});

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
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/auth/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bluePrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/auth/register');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bluePrimary,
                    side: const BorderSide(color: AppColors.bluePrimary, width: 2),
                  ),
                  child: const Text('Register'),
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
