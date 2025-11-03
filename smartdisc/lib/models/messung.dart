// lib/models/messung.dart
class Messung {
  final String id;
  final String wurfId;
  final String zeitpunkt;
  final double? ax;
  final double? ay;
  final double? az;
  final double? temperatur;

  Messung({
    required this.id,
    required this.wurfId,
    required this.zeitpunkt,
    this.ax,
    this.ay,
    this.az,
    this.temperatur,
  });

  factory Messung.fromJson(Map<String, dynamic> j) => Messung(
        id: j['id'].toString(),
        wurfId: j['wurf_id'] as String,
        zeitpunkt: j['zeitpunkt'] as String,
        ax: (j['beschleunigung_x'] as num?)?.toDouble(),
        ay: (j['beschleunigung_y'] as num?)?.toDouble(),
        az: (j['beschleunigung_z'] as num?)?.toDouble(),
        temperatur: (j['temperatur'] as num?)?.toDouble(),
      );
}
