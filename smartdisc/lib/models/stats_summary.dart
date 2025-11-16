import 'throw_model.dart';

class StatsSummary {
  StatsSummary({
    required this.totalThrows,
    required this.averageDistanceMeters,
    required this.averageMaxHeightMeters,
    required this.averageRotationRps,
  });

  final int totalThrows;
  final double averageDistanceMeters;
  final double averageMaxHeightMeters;
  final double averageRotationRps;

  factory StatsSummary.fromThrows(Iterable<Throw> throws) {
    final list = List<Throw>.from(throws);
    final total = list.length;
    if (total == 0) {
      return StatsSummary(
        totalThrows: 0,
        averageDistanceMeters: 0.0,
        averageMaxHeightMeters: 0.0,
        averageRotationRps: 0.0,
      );
    }

    double sumDist = 0.0;
    double sumHeight = 0.0;
    double sumRot = 0.0;
    for (final t in list) {
      sumDist += t.distanceMeters;
      sumHeight += t.maxHeightMeters;
      sumRot += t.maxRotationRps;
    }

    return StatsSummary(
      totalThrows: total,
      averageDistanceMeters: sumDist / total,
      averageMaxHeightMeters: sumHeight / total,
      averageRotationRps: sumRot / total,
    );
  }
}
