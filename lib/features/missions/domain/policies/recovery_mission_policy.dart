import '../entities/behavioral_history.dart';
import '../entities/user_discipline_profile.dart';

class RecoveryDecision {
  const RecoveryDecision({required this.active, required this.reason});

  final bool active;

  /// Non-shaming, neutral explanation — never "you failed" language.
  final String? reason;
}

/// Decides whether recovery mode should be active for this selection round.
/// Recovery only ever *narrows* choices toward short, achievable, known-safe
/// missions — it never erases history or blocks the user from leaving it.
abstract final class RecoveryMissionPolicy {
  static const _prolongedInactivityDays = 3;

  /// Recovery missions stay short regardless of how much time the user
  /// says they have available — see spec: "cap duration".
  static const recoveryDurationCapMinutes = 10;

  static RecoveryDecision resolve({
    required UserDisciplineProfile profile,
    required BehavioralHistory history,
    required DateTime currentDateTime,
    bool? override,
  }) {
    if (override != null) {
      return RecoveryDecision(
        active: override,
        reason: override ? 'Manually enabled.' : null,
      );
    }

    if (profile.recoveryModeActive) {
      return const RecoveryDecision(
        active: true,
        reason: 'Recovery mode is currently on.',
      );
    }

    if (history.consecutiveMisses >= 3) {
      return const RecoveryDecision(
        active: true,
        reason: 'A short, achievable mission to rebuild momentum.',
      );
    }

    if (history.lastCompletedAt != null) {
      final daysSince = currentDateTime
          .difference(history.lastCompletedAt!)
          .inDays;
      if (daysSince >= _prolongedInactivityDays) {
        return const RecoveryDecision(
          active: true,
          reason: 'Easing back in after some time away.',
        );
      }
    }

    if (history.completionRate7Days < 0.3 &&
        history.recentMissionResults.isNotEmpty) {
      return const RecoveryDecision(
        active: true,
        reason: 'One achievable mission is enough today.',
      );
    }

    if ((history.selfReportedEffortAverage ?? 0) >= 4.5) {
      return const RecoveryDecision(
        active: true,
        reason: 'Recent missions have felt like a lot — easing off.',
      );
    }

    return const RecoveryDecision(active: false, reason: null);
  }
}
