/// BLE Disc Measurement Model
/// Represents data received from ESP32 via BLE notifications
class BleDiscMeasurement {
  final String scheibeId;  // Disc ID as string
  final double hoehe;      // Height as double (meters)
  final double rotation;   // Rotation as double (rps - rotations per second)
  final double? accelerationMax; // Maximum acceleration (m/s²), optional

  BleDiscMeasurement({
    required this.scheibeId,
    required this.hoehe,
    required this.rotation,
    this.accelerationMax,
  });

  /// Parse from JSON with proper type handling and null safety
  /// Expected format: {"scheibe_id":"1","hoehe":1.25,"rotation":4.2,"acceleration_max":11.5}
  factory BleDiscMeasurement.fromJson(Map<String, dynamic> json) {
    try {
      return BleDiscMeasurement(
        scheibeId: (json['scheibe_id'] ?? json['scheibeId'] ?? '').toString(),
        hoehe: (json['hoehe'] ?? json['height'] as num?)?.toDouble() ?? 0.0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        accelerationMax: (json['acceleration_max'] ?? json['accelerationMax'] as num?)?.toDouble(),
      );
    } catch (e) {
      throw FormatException('Failed to parse BleDiscMeasurement: $e', json);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'scheibe_id': scheibeId,
      'hoehe': hoehe,
      'rotation': rotation,
      if (accelerationMax != null) 'acceleration_max': accelerationMax,
    };
  }

  @override
  String toString() {
    final accel = accelerationMax != null ? ', accelerationMax: $accelerationMax' : '';
    return 'BleDiscMeasurement(scheibeId: $scheibeId, hoehe: $hoehe, rotation: $rotation$accel)';
  }
}
