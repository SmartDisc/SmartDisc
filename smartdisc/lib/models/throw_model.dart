import 'dart:convert';

/// Single frisbee throw with aggregated sensor data
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
  final double rotation;
  final double height;
  final double accelerationMax;

  /// Convert to JSON. Uses snake_case for backend.
  /// Note: scheibe_id needs to be added separately in API calls.
  Map<String, dynamic> toJson() => {
        'id': id,
        'player_id': playerId,
        'rotation': rotation,
        'hoehe': height,
        'acceleration_max': accelerationMax,
      };

  factory Throw.fromJson(Map<String, dynamic> json) {
    // Accepts both snake_case and camelCase field names
    final timestampStr = json['erstellt_am'] ?? json['timestamp'] as String?;
    if (timestampStr == null) {
      throw FormatException('Missing timestamp field (erstellt_am or timestamp)');
    }
    
    return Throw(
      id: json['id'] as String,
      playerId: json['player_id'] ?? json['playerId'] as String? ?? '',
      timestamp: DateTime.parse(timestampStr),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      height: (json['hoehe'] ?? json['height'] as num?)?.toDouble() ?? 0.0,
      accelerationMax: (json['acceleration_max'] ?? json['accelerationMax'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
