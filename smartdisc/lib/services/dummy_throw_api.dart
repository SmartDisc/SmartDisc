import 'dart:async';

import '../models/throw_model.dart';
import '../models/stats_summary.dart';
import 'throw_api.dart';

/// Dummy in-memory implementation of [ThrowApi].
class DummyThrowApi implements ThrowApi {
  DummyThrowApi() {
    _init();
  }

  final List<Throw> _store = <Throw>[];

  void _init() {
    final now = DateTime.now();
    _store.addAll([
      Throw(
        id: 't1',
        playerId: 'p1',
        timestamp: now.subtract(const Duration(minutes: 3)),
        rotation: 3.3,
        height: 1.1,
        accelerationMax: 9.8,
      ),
      Throw(
        id: 't2',
        playerId: 'p2',
        timestamp: now.subtract(const Duration(minutes: 12)),
        rotation: 5.0,
        height: 2.7,
        accelerationMax: 12.5,
      ),
      Throw(
        id: 't3',
        playerId: 'p1',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
        rotation: 6.6,
        height: 3.4,
        accelerationMax: 15.2,
      ),
      Throw(
        id: 't4',
        playerId: 'p3',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 20)),
        rotation: 4.1,
        height: 2.0,
        accelerationMax: 11.3,
      ),
      Throw(
        id: 't5',
        playerId: 'p2',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        rotation: 9.0,
        height: 5.2,
        accelerationMax: 18.7,
      ),
      // additional dummy players p4, p5, p6
      Throw(
        id: 't6',
        playerId: 'p4',
        timestamp: now.subtract(const Duration(days: 2, hours: 1)),
        rotation: 4.8,
        height: 2.4,
        accelerationMax: 10.9,
      ),
      Throw(
        id: 't7',
        playerId: 'p5',
        timestamp: now.subtract(const Duration(days: 3, hours: 4)),
        rotation: 5.6,
        height: 3.0,
        accelerationMax: 13.1,
      ),
      Throw(
        id: 't8',
        playerId: 'p6',
        timestamp: now.subtract(const Duration(days: 4, hours: 2)),
        rotation: 3.9,
        height: 1.8,
        accelerationMax: 9.2,
      ),
    ]);
  }

  @override
  Future<List<Throw>> getThrows() async {
    // small artificial delay
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<Throw>.from(_store);
  }

  @override
  Future<Throw> getThrowById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    try {
      return _store.firstWhere((t) => t.id == id);
    } catch (_) {
      throw Exception('Throw $id not found');
    }
  }

  @override
  Future<StatsSummary> getStatsSummary() async {
    final list = await getThrows();
    return StatsSummary.fromThrows(list);
  }
}
