import 'wurf.dart';

enum ThrowSyncStatus {
  pending,
  synced,
  failed,
}

/// UI wrapper around a `Wurf` with sync metadata.
class UiThrow {
  UiThrow({
    required this.id,
    required this.wurf,
    required this.status,
  });

  /// Local identifier used on the client (can differ from backend id).
  final String id;

  /// The underlying throw data as returned by the backend model.
  final Wurf wurf;

  /// Sync state with the backend.
  final ThrowSyncStatus status;
}

