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

  /// Parse from JSON with proper type handling and null safety
  /// Expected format: {"scheibe_id":"1","hoehe":1.25,"rotation":4.2,"acceleration_x":2.1,"acceleration_y":1.5,"acceleration_z":15.3}
  factory BleDiscMeasurement.fromJson(Map<String, dynamic> json) {
    try {
      final accelX = (json['acceleration_x'] ?? json['accelerationX'] as num?)?.toDouble();
      final accelY = (json['acceleration_y'] ?? json['accelerationY'] as num?)?.toDouble();
      final accelZ = (json['acceleration_z'] ?? json['accelerationZ'] as num?)?.toDouble();
      
      // Calculate acceleration_max from components if not provided
      double? accelMax = (json['acceleration_max'] ?? json['accelerationMax'] as num?)?.toDouble();
      if (accelMax == null && (accelX != null || accelY != null || accelZ != null)) {
        final x = accelX ?? 0.0;
        final y = accelY ?? 0.0;
        final z = accelZ ?? 0.0;
        accelMax = (x * x + y * y + z * z).sqrt();
      }
      
      return BleDiscMeasurement(
        scheibeId: (json['scheibe_id'] ?? json['scheibeId'] ?? '').toString(),
        hoehe: (json['hoehe'] ?? json['height'] as num?)?.toDouble() ?? 0.0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
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
