import 'package:flutter/material.dart';
import '../services/assignment_service.dart';
import '../services/disc_service.dart';
import '../services/auth_service.dart';
import '../styles/app_font.dart';
import '../styles/app_colors.dart';

class DiscAssignmentsScreen extends StatefulWidget {
  const DiscAssignmentsScreen({super.key});

  @override
  State<DiscAssignmentsScreen> createState() => _DiscAssignmentsScreenState();
}

class _DiscAssignmentsScreenState extends State<DiscAssignmentsScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final DiscService _discService = DiscService.instance();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _discs = [];
  Map<String, List<Map<String, dynamic>>> _assignmentsByPlayer = {};
  bool _isLoading = true;
  String? _selectedPlayerId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final role = await _authService.currentUserRole();
      if (role != 'trainer') {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final players = await _assignmentService.getPlayers();
      await _discService.init();
      final discs = _discService.discs.value;

      final assignmentsMap = <String, List<Map<String, dynamic>>>{};
      for (final player in players) {
        final playerId = player['id'] as String;
        final assignments = await _assignmentService.getPlayerAssignments(playerId);
        assignmentsMap[playerId] = assignments;
      }

      setState(() {
        _players = players;
        _discs = discs;
        _assignmentsByPlayer = assignmentsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  Future<void> _assignDisc(String discId, String playerId) async {
    try {
      await _assignmentService.assignDisc(discId: discId, playerId: playerId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disc erfolgreich zugeordnet')),
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

  Future<void> _removeAssignment(int assignmentId, String playerId) async {
    try {
      await _assignmentService.removeAssignment(assignmentId);
      await _loadData();
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

  Widget _buildPlayerSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spieler auswählen', style: AppFont.headline),
            const SizedBox(height: 12),
            DropdownButton<String?>(
              value: _selectedPlayerId,
              hint: const Text('Spieler wählen...'),
              isExpanded: true,
              items: _players.map((player) {
                final id = player['id'] as String;
                final name = '${player['first_name']} ${player['last_name']}';
                final email = player['email'] as String;
                return DropdownMenuItem<String?>(
                  value: id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(email, style: AppFont.caption),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPlayerId = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsList() {
    if (_selectedPlayerId == null) {
      return const Center(
        child: Text('Bitte einen Spieler auswählen'),
      );
    }

    final assignments = _assignmentsByPlayer[_selectedPlayerId] ?? [];
    final assignedDiscIds = assignments.map((a) => a['disc_id'] as String).toSet();
    final availableDiscs = _discs.where((d) => !assignedDiscIds.contains(d['id'])).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assigned discs
        if (assignments.isNotEmpty) ...[
          Text('Zugeordnete Discs', style: AppFont.headline),
          const SizedBox(height: 8),
          ...assignments.map((assignment) {
            final discId = assignment['disc_id'] as String;
            final discName = assignment['disc_name'] as String? ?? discId;
            final assignmentId = assignment['id'] as int;
            return Card(
              child: ListTile(
                title: Text(discName),
                subtitle: Text('ID: $discId'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeAssignment(assignmentId, _selectedPlayerId!),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],

        // Available discs to assign
        Text('Verfügbare Discs', style: AppFont.headline),
        const SizedBox(height: 8),
        if (availableDiscs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Alle Discs sind bereits zugeordnet'),
          )
        else
          ...availableDiscs.map((disc) {
            final discId = disc['id'] as String;
            final discName = disc['name'] as String? ?? discId;
            return Card(
              child: ListTile(
                title: Text(discName),
                subtitle: Text('ID: $discId'),
                trailing: IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _assignDisc(discId, _selectedPlayerId!),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlayerSelector(),
                    const SizedBox(height: 24),
                    _buildAssignmentsList(),
                  ],
                ),
              ),
            ),
    );
  }
}
