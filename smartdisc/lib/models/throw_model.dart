import 'dart:convert';

/// Model representing a single frisbee throw.
class Throw {
  Throw({
    required this.id,
    required this.playerId,
    required this.timestamp,
    required this.distanceMeters,
    required this.maxHeightMeters,
    required this.maxRotationRps,
  });

  final String id;
  final String playerId;
  final DateTime timestamp;
  final double distanceMeters;
  final double maxHeightMeters;
  final double maxRotationRps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'timestamp': timestamp.toIso8601String(),
        'distanceMeters': distanceMeters,
        'maxHeightMeters': maxHeightMeters,
        'maxRotationRps': maxRotationRps,
      };

  factory Throw.fromJson(Map<String, dynamic> json) => Throw(
        id: json['id'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        maxHeightMeters: (json['maxHeightMeters'] as num).toDouble(),
        maxRotationRps: (json['maxRotationRps'] as num).toDouble(),
      );

  @override
  String toString() => jsonEncode(toJson());
}
