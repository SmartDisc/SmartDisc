import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

class DiscAssignmentScreen extends StatefulWidget {
  const DiscAssignmentScreen({super.key});

  @override
  State<DiscAssignmentScreen> createState() => _DiscAssignmentScreenState();
}

class _DiscAssignmentScreenState extends State<DiscAssignmentScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _allDiscs = [];
  bool _isLoading = true;
  String? _selectedPlayerId;
  List<Map<String, dynamic>> _playerDiscs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final players = await _api.getPlayers();
      final discs = await _api.getDiscs();
      setState(() {
        _players = players;
        _allDiscs = discs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _loadPlayerDiscs(String playerId) async {
    try {
      final discs = await _api.getPlayerDiscs(playerId);
      setState(() {
        _selectedPlayerId = playerId;
        _playerDiscs = discs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  Future<void> _assignDisc(String discId) async {
    if (_selectedPlayerId == null) return;
    try {
      await _api.assignDiscToPlayer(_selectedPlayerId!, discId);
      await _loadPlayerDiscs(_selectedPlayerId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disc zugeordnet')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _removeDisc(String discId) async {
    if (_selectedPlayerId == null) return;
    try {
      await _api.removeDiscFromPlayer(_selectedPlayerId!, discId);
      await _loadPlayerDiscs(_selectedPlayerId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zuordnung entfernt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Spieler auswählen', style: AppFont.headline),
          const SizedBox(height: 16),
          ..._players.map((player) {
            final isSelected = _selectedPlayerId == player['id'];
            return Card(
              color: isSelected ? AppColors.bluePrimary.withAlpha(51) : null,
              child: ListTile(
                title: Text(
                  '${player['first_name']} ${player['last_name']}',
                  style: AppFont.subheadline,
                ),
                subtitle: Text(player['email'] ?? '', style: AppFont.body),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.bluePrimary)
                    : null,
                onTap: () => _loadPlayerDiscs(player['id'] as String),
              ),
            );
          }),
          if (_selectedPlayerId != null) ...[
            const SizedBox(height: 32),
            Text('Zugeordnete Discs', style: AppFont.headline),
            const SizedBox(height: 16),
            if (_playerDiscs.isEmpty)
              const Text('Keine Discs zugeordnet', style: AppFont.body)
            else
              ..._playerDiscs.map((disc) {
                return Card(
                  child: ListTile(
                    title: Text(disc['name'] ?? disc['id'] ?? '', style: AppFont.subheadline),
                    subtitle: Text(disc['id'] ?? '', style: AppFont.caption),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeDisc(disc['id'] as String),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
            Text('Disc zuordnen', style: AppFont.headline),
            const SizedBox(height: 16),
            ..._allDiscs.where((disc) {
              return !_playerDiscs.any((pd) => pd['id'] == disc['id']);
            }).map((disc) {
              return Card(
                child: ListTile(
                  title: Text(disc['name'] ?? disc['id'] ?? '', style: AppFont.subheadline),
                  subtitle: Text(disc['id'] ?? '', style: AppFont.caption),
                  trailing: IconButton(
                    icon: const Icon(Icons.add, color: AppColors.bluePrimary),
                    onPressed: () => _assignDisc(disc['id'] as String),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
