import '../models/throw_model.dart';
import '../models/stats_summary.dart';

/// API interface for throws
abstract class ThrowApi {
  Future<List<Throw>> getThrows();

  Future<Throw> getThrowById(String id);

  Future<Throw> createThrow({
    required String scheibeId,
    String? playerId,
    required double rotation,
    required double height,
    required double accelerationMax,
  });

  Future<StatsSummary> getStatsSummary();
}
