import 'dart:math' as math;

/// BLE Disc Measurement Model
/// Represents data received from ESP32 via BLE notifications
class BleDiscMeasurement {
  final String scheibeId;  // Disc ID as string
  final double hoehe;      // Height as double (meters)
  final double rotation;   // Rotation as double (rps - rotations per second)
  final double? accelerationX; // X-axis acceleration (m/s²), optional
  final double? accelerationY; // Y-axis acceleration (m/s²), optional
  final double? accelerationZ; // Z-axis acceleration (m/s²), optional
  final double? accelerationMax; // Maximum acceleration (m/s²), optional (calculated from X/Y/Z if not provided)

  BleDiscMeasurement({
    required this.scheibeId,
    required this.hoehe,
    required this.rotation,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.accelerationMax,
  });

  /// Parse from JSON with proper type handling and null safety.
  ///
  /// Supported input formats:
  /// - Legacy backend-style:
  ///   {"scheibe_id":"1","hoehe":1.25,"rotation":4.2,"acceleration_x":2.1,"acceleration_y":1.5,"acceleration_z":15.3}
  /// - ESP32 ground station BLE format:
  ///   {"id": 1, "height_m": 1.23, "ax_ms2": 0.1, "ay_ms2": 0.2, "az_ms2": 9.8, "gyro_dps": 360.0}
  factory BleDiscMeasurement.fromJson(Map<String, dynamic> json) {
    try {
      // Map acceleration components:
      // - Backend-style: acceleration_x / acceleration_y / acceleration_z
      // - ESP-style: ax_ms2 / ay_ms2 / az_ms2
      double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

      final accelX = _toDouble(
        json.containsKey('acceleration_x')
            ? json['acceleration_x']
            : json.containsKey('accelerationX')
                ? json['accelerationX']
                : json['ax_ms2'],
      );
      final accelY = _toDouble(
        json.containsKey('acceleration_y')
            ? json['acceleration_y']
            : json.containsKey('accelerationY')
                ? json['accelerationY']
                : json['ay_ms2'],
      );
      final accelZ = _toDouble(
        json.containsKey('acceleration_z')
            ? json['acceleration_z']
            : json.containsKey('accelerationZ')
                ? json['accelerationZ']
                : json['az_ms2'],
      );
      
      // Calculate acceleration_max from components if not provided
      double? accelMax = _toDouble(
        json.containsKey('acceleration_max')
            ? json['acceleration_max']
            : json['accelerationMax'],
      );
      if (accelMax == null && (accelX != null || accelY != null || accelZ != null)) {
        final x = accelX ?? 0.0;
        final y = accelY ?? 0.0;
        final z = accelZ ?? 0.0;
        accelMax = math.sqrt(x * x + y * y + z * z);
      }
      
      // Map disc ID:
      // - Backend-style: scheibe_id / scheibeId
      // - ESP-style: id
      final rawId = json.containsKey('scheibe_id')
          ? json['scheibe_id']
          : (json.containsKey('scheibeId') ? json['scheibeId'] : json['id']);

      // Map height:
      // - Backend-style: hoehe / height
      // - ESP-style: height_m
      final rawHeight = json.containsKey('hoehe')
          ? json['hoehe']
          : (json.containsKey('height')
              ? json['height']
              : json['height_m']);

      // Map rotation:
      // - Backend-style: rotation (already numeric)
      // - ESP-style: gyro_dps (we forward as-is to backend)
      final rawRotation = json.containsKey('rotation')
          ? json['rotation']
          : json['gyro_dps'];

      return BleDiscMeasurement(
        scheibeId: (rawId ?? '').toString(),
        hoehe: _toDouble(rawHeight) ?? 0.0,
        rotation: _toDouble(rawRotation) ?? 0.0,
        accelerationX: accelX,
        accelerationY: accelY,
        accelerationZ: accelZ,
        accelerationMax: accelMax,
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
      if (accelerationX != null) 'acceleration_x': accelerationX,
      if (accelerationY != null) 'acceleration_y': accelerationY,
      if (accelerationZ != null) 'acceleration_z': accelerationZ,
      if (accelerationMax != null) 'acceleration_max': accelerationMax,
    };
  }

  @override
  String toString() {
    final parts = <String>['scheibeId: $scheibeId', 'hoehe: $hoehe', 'rotation: $rotation'];
    if (accelerationX != null || accelerationY != null || accelerationZ != null) {
      parts.add('accel: X=$accelerationX Y=$accelerationY Z=$accelerationZ');
    }
    if (accelerationMax != null) {
      parts.add('accelMax: $accelerationMax');
    }
    return 'BleDiscMeasurement(${parts.join(', ')})';
  }
}
