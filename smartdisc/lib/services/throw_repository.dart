import 'dart:async';

import '../models/ble_disc_measurement.dart';
import '../models/ui_throw.dart';
import '../models/wurf.dart';
import 'api_service.dart';

/// Minimal repository that:
/// - converts BLE measurements into `Wurf`/`UiThrow`
/// - updates an in-memory list for the UI
/// - sends throws to the backend in the background
class ThrowRepository {
  ThrowRepository({
    required ApiService apiService,
    required void Function(List<UiThrow>) onStateChanged,
  })  : _apiService = apiService,
        _onStateChanged = onStateChanged;

  final ApiService _apiService;
  final void Function(List<UiThrow>) _onStateChanged;

  final List<UiThrow> _liveThrows = [];
  int _nextLocalId = 0;

  /// Current live throws (read-only snapshot).
  List<UiThrow> get liveThrows => List.unmodifiable(_liveThrows);

  /// Handle a new BLE measurement coming from the ground station.
  ///
  /// - immediately adds it to the in-memory list for instant UI feedback
  /// - triggers an async POST to the backend
  void addBleMeasurement(BleDiscMeasurement m) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final wurf = Wurf(
      id: 'live_${_nextLocalId++}',
      scheibeId: m.scheibeId,
      rotation: m.rotation,
      hoehe: m.hoehe,
      accelerationX: m.accelerationX,
      accelerationY: m.accelerationY,
      accelerationZ: m.accelerationZ,
      accelerationMax: m.accelerationMax,
      erstelltAm: nowIso,
    );

    final uiThrow = UiThrow(
      id: wurf.id,
      wurf: wurf,
      status: ThrowSyncStatus.pending,
    );

    _liveThrows.insert(0, uiThrow);
    _notify();

    // Fire-and-forget backend sync.
    unawaited(_syncToBackend(uiThrow, m));
  }

  Future<void> _syncToBackend(UiThrow uiThrow, BleDiscMeasurement m) async {
    try {
      await _apiService.createThrow(
        scheibeId: m.scheibeId,
        rotation: m.rotation,
        height: m.hoehe,
        accelerationX: m.accelerationX,
        accelerationY: m.accelerationY,
        accelerationZ: m.accelerationZ,
        accelerationMax: m.accelerationMax,
      );
      _updateStatus(uiThrow.id, ThrowSyncStatus.synced);
    } catch (_) {
      _updateStatus(uiThrow.id, ThrowSyncStatus.failed);
    }
  }

  void _updateStatus(String id, ThrowSyncStatus status) {
    final idx = _liveThrows.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final current = _liveThrows[idx];
    _liveThrows[idx] = UiThrow(
      id: current.id,
      wurf: current.wurf,
      status: status,
    );
    _notify();
  }

  void _notify() {
    _onStateChanged(List<UiThrow>.from(_liveThrows));
  }
}

