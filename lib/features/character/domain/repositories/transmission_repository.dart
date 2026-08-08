import '../../../dashboard/domain/entities/dashboard_overview.dart';
import '../entities/transmission_script.dart';

/// Thrown by [TransmissionRepository.getDailyTransmission] when no script
/// could be produced — the controller decides how to degrade from there
/// (retry, cached fallback, accessible summary).
class TransmissionException implements Exception {
  const TransmissionException(this.message);

  final String message;

  @override
  String toString() => 'TransmissionException: $message';
}

/// A more specific failure: the device has no connection and nothing is
/// cached locally. The controller surfaces this as an accessible fallback
/// mission summary rather than a bare error.
class TransmissionOfflineException implements Exception {
  const TransmissionOfflineException();
}

/// Supplies today's [TransmissionScript]. Only a [MockTransmissionRepository]
/// exists in this phase — a Supabase/AI-backed implementation is a later
/// roadmap item.
abstract class TransmissionRepository {
  Future<TransmissionScript> getDailyTransmission(DashboardOverview dashboard);
}
