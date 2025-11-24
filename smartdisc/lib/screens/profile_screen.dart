import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../styles/app_font.dart';
import '../styles/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  late Future<_ProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_ProfileData> _loadProfile() async {
    final email = await _auth.currentUserEmail();
    final role = await _auth.currentUserRole();
    return _ProfileData(email: email, role: role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<_ProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceMuted,
                      ),
                      child: const Icon(Icons.person, size: 42),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data.role ?? 'Unknown').toUpperCase(),
                          style: AppFont.subheadline.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.email ?? 'No email stored',
                          style: AppFont.headline.copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Account details', style: AppFont.headline),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Email'),
                  subtitle: Text(data.email ?? 'Not available'),
                  leading: const Icon(Icons.email_outlined),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Role'),
                  subtitle: Text(
                    data.role != null
                        ? data.role![0].toUpperCase() + data.role!.substring(1)
                        : 'Not selected',
                  ),
                  leading: const Icon(Icons.badge_outlined),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileData {
  final String? email;
  final String? role;
  _ProfileData({required this.email, required this.role});
}
