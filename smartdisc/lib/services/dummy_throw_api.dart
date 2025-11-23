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
        distanceMeters: 12.4,
        maxHeightMeters: 1.1,
        maxRotationRps: 3.3,
      ),
      Throw(
        id: 't2',
        playerId: 'p2',
        timestamp: now.subtract(const Duration(minutes: 12)),
        distanceMeters: 23.8,
        maxHeightMeters: 2.7,
        maxRotationRps: 5.0,
      ),
      Throw(
        id: 't3',
        playerId: 'p1',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
        distanceMeters: 30.2,
        maxHeightMeters: 3.4,
        maxRotationRps: 6.6,
      ),
      Throw(
        id: 't4',
        playerId: 'p3',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 20)),
        distanceMeters: 18.9,
        maxHeightMeters: 2.0,
        maxRotationRps: 4.1,
      ),
      Throw(
        id: 't5',
        playerId: 'p2',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        distanceMeters: 41.7,
        maxHeightMeters: 5.2,
        maxRotationRps: 9.0,
      ),
      // additional dummy players p4, p5, p6
      Throw(
        id: 't6',
        playerId: 'p4',
        timestamp: now.subtract(const Duration(days: 2, hours: 1)),
        distanceMeters: 28.3,
        maxHeightMeters: 2.4,
        maxRotationRps: 4.8,
      ),
      Throw(
        id: 't7',
        playerId: 'p5',
        timestamp: now.subtract(const Duration(days: 3, hours: 4)),
        distanceMeters: 35.6,
        maxHeightMeters: 3.0,
        maxRotationRps: 5.6,
      ),
      Throw(
        id: 't8',
        playerId: 'p6',
        timestamp: now.subtract(const Duration(days: 4, hours: 2)),
        distanceMeters: 22.1,
        maxHeightMeters: 1.8,
        maxRotationRps: 3.9,
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
