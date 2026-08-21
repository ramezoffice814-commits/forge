import 'package:flutter/foundation.dart';

/// Where a resolved mission assignment actually came from (spec section
/// 18's three-tier hierarchy) — never itself a claim about reward
/// eligibility; that's [ResolvedMissionAssignment.isProvisional]'s job,
/// enforced structurally by the rest of the backend layer (only a real
/// `submit-mission` server response can ever produce a
/// [ServerConfirmedValue] — see `core/security/authoritative_value.dart`
/// — so a provisional-sourced assignment already cannot earn confirmed
/// reward without going through that same real round trip; nothing
/// extra is needed here to enforce it).
enum MissionAssignmentSource {
  /// A confirmed assignment already cached from a prior successful
  /// server response — the strongest tier: safe to treat as
  /// authoritative without another round trip.
  cachedConfirmed,

  /// An existing local mission this session already knows about
  /// (queued/in-progress) that is still valid for today — reused rather
  /// than fabricating a new one out from under the user.
  existingProvisional,

  /// No authoritative or existing local assignment was reachable —
  /// falls back to whatever the local mock engine would produce,
  /// clearly marked provisional. Never claims server confirmation.
  offlineFallback,
}

@immutable
class ResolvedMissionAssignment {
  const ResolvedMissionAssignment({
    required this.source,
    required this.missionInstanceId,
  });

  final MissionAssignmentSource source;
  final String missionInstanceId;

  bool get isProvisional => source != MissionAssignmentSource.cachedConfirmed;
}

/// Pure, deterministic resolution of spec section 18's preferred
/// hierarchy — no I/O, no clock reads; every input is already resolved
/// by the caller (a cache lookup, a local-repository lookup, a fallback
/// mission builder), so this is trivially unit-testable and never
/// itself decides *how* to reach the network.
abstract final class OfflineMissionAssignmentResolver {
  static ResolvedMissionAssignment resolve({
    required String? cachedConfirmedMissionInstanceId,
    required String? existingValidProvisionalMissionInstanceId,
    required String Function() buildOfflineFallbackMissionInstanceId,
  }) {
    if (cachedConfirmedMissionInstanceId != null) {
      return ResolvedMissionAssignment(
        source: MissionAssignmentSource.cachedConfirmed,
        missionInstanceId: cachedConfirmedMissionInstanceId,
      );
    }
    if (existingValidProvisionalMissionInstanceId != null) {
      return ResolvedMissionAssignment(
        source: MissionAssignmentSource.existingProvisional,
        missionInstanceId: existingValidProvisionalMissionInstanceId,
      );
    }
    return ResolvedMissionAssignment(
      source: MissionAssignmentSource.offlineFallback,
      missionInstanceId: buildOfflineFallbackMissionInstanceId(),
    );
  }
}
