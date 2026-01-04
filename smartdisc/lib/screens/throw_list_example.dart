import 'package:flutter/material.dart';

import '../models/throw_model.dart';
import '../services/throw_api.dart';
import '../services/dummy_throw_api.dart';

/// Small example widget that uses [ThrowApi.getThrows] via FutureBuilder
/// and displays the result in a ListView.
class ThrowListExample extends StatelessWidget {
  const ThrowListExample({super.key, this.api});

  final ThrowApi? api;

  ThrowApi get _api => api ?? DummyThrowApi();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Throws (Dummy)')),
      body: FutureBuilder<List<Throw>>(
        future: _api.getThrows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? <Throw>[];
          if (items.isEmpty) {
            return const Center(child: Text('No throws available'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = items[index];
              return ListTile(
                title: Text('Rotation: ${t.rotation.toStringAsFixed(2)} rps — Height: ${t.height.toStringAsFixed(2)} m'),
                subtitle: Text('${t.playerId} • ${t.timestamp.toLocal()}'),
                trailing: Text('${t.accelerationMax.toStringAsFixed(2)} m/s²'),
              );
            },
          );
        },
      ),
    );
  }
}
