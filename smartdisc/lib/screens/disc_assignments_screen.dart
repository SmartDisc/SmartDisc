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

  bool _isLoading = true;
  String? _loadError;

  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _discs = [];
  Map<String, List<Map<String, dynamic>>> _assignmentsByPlayer = {};

  String? _selectedPlayerId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final role = await _authService.currentUserRole();
      if (role != 'trainer') {
        setState(() {
          _isLoading = false;
          _loadError = 'Nur Trainer dürfen Discs zuordnen.';
        });
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
        _loadError = null;
        _selectedPlayerId ??= players.isNotEmpty ? players.first['id'] as String : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _assignDisc(String discId, String playerId) async {
    try {
      await _assignmentService.assignDisc(discId: discId, playerId: playerId);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disc erfolgreich zugeordnet')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _removeAssignment(int assignmentId) async {
    final playerId = _selectedPlayerId;
    if (playerId == null) return;
    try {
      await _assignmentService.removeAssignment(assignmentId);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zuordnung entfernt')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Widget _buildPlayerSelector() {
    if (_players.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Keine Spieler (Role \"player\") vorhanden.'),
        ),
      );
    }

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
              isExpanded: true,
              hint: const Text('Spieler wählen...'),
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

  Widget _buildAssignments() {
    final playerId = _selectedPlayerId;
    if (playerId == null) {
      return const Center(child: Text('Bitte einen Spieler auswählen'));
    }

    final assignments = _assignmentsByPlayer[playerId] ?? [];
    final assignedDiscIds = assignments.map((a) => a['disc_id'] as String).toSet();
    final availableDiscs = _discs.where((d) => !assignedDiscIds.contains(d['id'])).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assignments.isNotEmpty) ...[
          Text('Zugeordnete Discs', style: AppFont.headline),
          const SizedBox(height: 8),
          ...assignments.map((assignment) {
            final discId = assignment['disc_id'] as String;
            final discName = (assignment['disc_name'] as String?) ?? discId;
            final assignmentId = assignment['id'] as int;
            return Card(
              child: ListTile(
                title: Text(discName),
                subtitle: Text('ID: $discId'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeAssignment(assignmentId),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
        Text('Verfügbare Discs', style: AppFont.headline),
        const SizedBox(height: 8),
        if (availableDiscs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Alle Discs sind diesem Spieler bereits zugeordnet.'),
          )
        else
          ...availableDiscs.map((disc) {
            final discId = disc['id'] as String;
            final discName = (disc['name'] as String?) ?? discId;
            return Card(
              child: ListTile(
                title: Text(discName),
                subtitle: Text('ID: $discId'),
                trailing: IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _assignDisc(discId, playerId),
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
      appBar: AppBar(
        title: const Text('Disc Assignments'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _loadError!,
                      style: AppFont.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPlayerSelector(),
                        const SizedBox(height: 24),
                        _buildAssignments(),
                      ],
                    ),
                  ),
                ),
    );
  }
}

