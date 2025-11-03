// lib/models/wurf.dart
class Wurf {
  final String id;
  final String? scheibeId;
  final double? entfernung;
  final double? geschwindigkeit;
  final String? erstelltAm;

  Wurf({
    required this.id,
    this.scheibeId,
    this.entfernung,
    this.geschwindigkeit,
    this.erstelltAm,
  });

  factory Wurf.fromJson(Map<String, dynamic> j) => Wurf(
        id: j['id'].toString(),
        scheibeId: j['scheibe_id'] as String?,
        entfernung: (j['entfernung'] as num?)?.toDouble(),
        geschwindigkeit: (j['geschwindigkeit'] as num?)?.toDouble(),
        erstelltAm: j['erstellt_am'] as String?,
      );
}
