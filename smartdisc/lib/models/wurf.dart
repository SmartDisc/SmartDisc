// lib/models/wurf.dart
class Wurf {
  final String id;
  final String? scheibeId;
  final double? rotation; // rps or degrees depending on source
  final double? hoehe; // height in meters
  final double? accelerationMax; // maximum acceleration in m/s²
  final String? erstelltAm;

  Wurf({
    required this.id,
    this.scheibeId,
    this.rotation,
    this.hoehe,
    this.accelerationMax,
    this.erstelltAm,
  });

  factory Wurf.fromJson(Map<String, dynamic> j) => Wurf(
        id: j['id'].toString(),
        scheibeId: j['scheibe_id'] as String?,
        // rotation may come from measurement aggregation or direct field
        rotation: (j['rotation'] as num?)?.toDouble(),
        // accept either 'hoehe' or 'height'
        hoehe: (j['hoehe'] ?? j['height'] as num?)?.toDouble(),
        // accept either 'acceleration_max' or 'accelerationMax'
        accelerationMax: (j['acceleration_max'] ?? j['accelerationMax'] as num?)?.toDouble(),
        erstelltAm: j['erstellt_am'] as String?,
      );
}
