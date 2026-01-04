import 'throw_model.dart';

class StatsSummary {
  StatsSummary({
    required this.totalThrows,
    required this.averageRotation,
    required this.averageHeight,
    required this.averageAccelerationMax,
  });

  final int totalThrows;
  final double averageRotation;
  final double averageHeight;
  final double averageAccelerationMax;

  factory StatsSummary.fromThrows(Iterable<Throw> throws) {
    final list = List<Throw>.from(throws);
    final total = list.length;
    if (total == 0) {
      return StatsSummary(
        totalThrows: 0,
        averageRotation: 0.0,
        averageHeight: 0.0,
        averageAccelerationMax: 0.0,
      );
    }

    double sumRotation = 0.0;
    double sumHeight = 0.0;
    double sumAccel = 0.0;
    for (final t in list) {
      sumRotation += t.rotation;
      sumHeight += t.height;
      sumAccel += t.accelerationMax;
    }

    return StatsSummary(
      totalThrows: total,
      averageRotation: sumRotation / total,
      averageHeight: sumHeight / total,
      averageAccelerationMax: sumAccel / total,
    );
  }
}
