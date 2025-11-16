import 'package:flutter/material.dart';
import '../styles/app_font.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.person, size: 72),
            SizedBox(height: 12),
            Text('Profile', style: AppFont.headline),
            SizedBox(height: 8),
            Text('User settings and account info.'),
          ],
        ),
      ),
    );
  }
}
