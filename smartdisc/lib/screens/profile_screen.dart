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
  late final Future<_ProfileData> _future = _loadProfile();

  Future<_ProfileData> _loadProfile() async {
    final auth = AuthService();
    final email = await auth.currentUserEmail();
    final role = await auth.currentUserRole();
    return _ProfileData(email: email, role: role);
  }

  String _roleLabel(String? role) {
    return (role ?? 'Unknown').toUpperCase();
  }

  String _formatRole(String? role) {
    if (role == null) return 'Not selected';
    return role[0].toUpperCase() + role.substring(1);
  }

  Widget _buildHeader(_ProfileData data) {
    return Row(
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
              _roleLabel(data.role),
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
    );
  }

  Widget _buildDetails(_ProfileData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          subtitle: Text(_formatRole(data.role)),
          leading: const Icon(Icons.badge_outlined),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final auth = AuthService();
              await auth.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/auth');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ProfileData>(
        future: _future,
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
                _buildHeader(data),
                const SizedBox(height: 32),
                _buildDetails(data),
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
