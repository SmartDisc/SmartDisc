import 'dart:convert';

/// Model representing a single frisbee throw.
/// Stores only aggregated values provided by hardware: rotation, height, acceleration_max
class Throw {
  Throw({
    required this.id,
    required this.playerId,
    required this.timestamp,
    required this.rotation,
    required this.height,
    required this.accelerationMax,
  });

  final String id;
  final String playerId;
  final DateTime timestamp;
  final double rotation; // rotation in rps
  final double height; // height in meters
  final double accelerationMax; // peak acceleration value

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'timestamp': timestamp.toIso8601String(),
        'rotation': rotation,
        'height': height,
        'accelerationMax': accelerationMax,
      };

  factory Throw.fromJson(Map<String, dynamic> json) => Throw(
        id: json['id'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        rotation: (json['rotation'] as num).toDouble(),
        height: (json['height'] ?? json['hoehe'] ?? json['maxHeightMeters'] as num?)?.toDouble() ?? 0.0,
        accelerationMax: (json['accelerationMax'] ?? json['acceleration_max'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() => jsonEncode(toJson());
}
