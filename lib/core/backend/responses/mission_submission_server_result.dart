import 'package:flutter/foundation.dart';

import '../../security/authoritative_value.dart';
import 'progression_update_summary.dart';
import 'server_validation_status.dart';

/// The richest response contract — everything a submitted mission can
/// confirm. Every reward-shaped field is wrapped in [AuthoritativeValue]
/// (concretely always a [ServerConfirmedValue] here, since this whole
/// object only ever exists after a real [RawBackendResponse] was
/// unwrapped) so it carries its trust level with it if it flows further
/// into progression/competition state later.
///
/// Backend calculation itself stays mocked in this phase — see
/// `MockBackendClient` for how these are fabricated deterministically.
@immutable
class MissionSubmissionServerResult {
  const MissionSubmissionServerResult({
    required this.status,
    required this.missionInstanceId,
    required this.confirmedMissionState,
    required this.confirmedXpReward,
    required this.progressionUpdate,
    required this.achievementUpdates,
    required this.competitionScoreUpdate,
    required this.integrityStatus,
    required this.serverTimestamp,
    required this.confirmationId,
    this.reasons = const [],
  });

  final ServerValidationStatus status;
  final String missionInstanceId;
  final MissionServerState confirmedMissionState;

  final AuthoritativeValue<int> confirmedXpReward;
  final AuthoritativeValue<ProgressionUpdateSummary> progressionUpdate;
  final AuthoritativeValue<List<String>> achievementUpdates;
  final AuthoritativeValue<double> competitionScoreUpdate;

  final ServerIntegrityStatus integrityStatus;
  final DateTime serverTimestamp;
  final String confirmationId;
  final List<String> reasons;
}
