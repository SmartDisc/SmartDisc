// lib/models/wurf.dart
import 'dart:math' show sqrt;

class Wurf {
  final String id;
  final String? scheibeId;
  final double? rotation; // rps or degrees depending on source
  final double? hoehe; // height in meters
  final double? accelerationX; // X-axis acceleration in m/s²
  final double? accelerationY; // Y-axis acceleration in m/s²
  final double? accelerationZ; // Z-axis acceleration in m/s²
  final double? accelerationMax; // maximum acceleration in m/s²
  final String? erstelltAm;

  Wurf({
    required this.id,
    this.scheibeId,
    this.rotation,
    this.hoehe,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.accelerationMax,
    this.erstelltAm,
  });

  factory Wurf.fromJson(Map<String, dynamic> j) {
    final accelX = (j['acceleration_x'] ?? j['accelerationX'] as num?)?.toDouble();
    final accelY = (j['acceleration_y'] ?? j['accelerationY'] as num?)?.toDouble();
    final accelZ = (j['acceleration_z'] ?? j['accelerationZ'] as num?)?.toDouble();
    
    // Calculate acceleration_max from components if not provided
    double? accelMax = (j['acceleration_max'] ?? j['accelerationMax'] as num?)?.toDouble();
    if (accelMax == null && (accelX != null || accelY != null || accelZ != null)) {
      final x = accelX ?? 0.0;
      final y = accelY ?? 0.0;
      final z = accelZ ?? 0.0;
      accelMax = sqrt(x * x + y * y + z * z);
    }
    
    return Wurf(
      id: j['id'].toString(),
      scheibeId: j['scheibe_id'] as String?,
      // rotation may come from measurement aggregation or direct field
      rotation: (j['rotation'] as num?)?.toDouble(),
      // accept either 'hoehe' or 'height'
      hoehe: (j['hoehe'] ?? j['height'] as num?)?.toDouble(),
      // accept acceleration components
      accelerationX: accelX,
      accelerationY: accelY,
      accelerationZ: accelZ,
      accelerationMax: accelMax,
      erstelltAm: j['erstellt_am'] as String?,
    );
  }
}
