// lib/models/wurf.dart
class Wurf {
  final String id;
  final String? scheibeId;
  final double? entfernung;
  final double? geschwindigkeit; // m/s or source 'speed'
  final double? rotation; // rps or degrees depending on source
  final double? hoehe; // height in meters
  final String? erstelltAm;

  Wurf({
    required this.id,
    this.scheibeId,
    this.entfernung,
    this.geschwindigkeit,
    this.rotation,
    this.hoehe,
    this.erstelltAm,
  });

  factory Wurf.fromJson(Map<String, dynamic> j) => Wurf(
        id: j['id'].toString(),
        scheibeId: j['scheibe_id'] as String?,
        entfernung: (j['entfernung'] as num?)?.toDouble(),
        // accept either 'geschwindigkeit' or 'speed' from various sources
        geschwindigkeit: (j['geschwindigkeit'] ?? j['speed'] as num?)?.toDouble(),
        // rotation may come from measurement aggregation or direct field
        rotation: (j['rotation'] as num?)?.toDouble(),
        // accept either 'hoehe' or 'height'
        hoehe: (j['hoehe'] ?? j['height'] as num?)?.toDouble(),
        erstelltAm: j['erstellt_am'] as String?,
      );
}
