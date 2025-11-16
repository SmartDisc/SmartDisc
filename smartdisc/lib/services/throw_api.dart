import '../models/throw_model.dart';
import '../models/stats_summary.dart';

/// Simple API interface for throws. No implementation here.
abstract class ThrowApi {
  Future<List<Throw>> getThrows();

  Future<Throw> getThrowById(String id);

  Future<StatsSummary> getStatsSummary();
}
