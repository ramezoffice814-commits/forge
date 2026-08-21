import 'package:flutter/foundation.dart';

import '../responses/server_validation_status.dart';

/// What happened when a locally-queued/provisional mission command met
/// the server's actual verdict. Deliberately narrower than the full set
/// of stable error codes (`supabase/functions/_shared/errors.ts`) —
/// several distinct codes collapse into the same *reconciliation*
/// behavior (e.g. `mission_not_found`/`forbidden`/`invalid_payload` are
/// all just [rejectedByServer]; there's nothing reconciliation-specific
/// to do differently between them, only the user-facing message differs
/// — see `backend_error_ux.dart` for that mapping).
enum ReconciliationOutcome {
  /// The provisional local state already agrees with what the server
  /// confirmed — nothing to change, just mark it confirmed.
  exactMatch,

  /// The command was genuinely new and the server accepted it —
  /// provisional state is promoted to server-confirmed.
  accepted,

  /// The server rejected the command outright (invalid transition,
  /// completion requirements not met, not found, forbidden, etc.) —
  /// the provisional attempt did not happen; local state must not claim
  /// it did.
  rejectedByServer,

  /// The command's sequence was already superseded — local state is
  /// behind what actually happened; the queued command must be dropped,
  /// not retried, and the mission's local aggregate should be
  /// refreshed/reconciled from the next confirmed response.
  staleSequence,

  /// The server is ahead of what this command expected (an
  /// out-of-order rejection) — an earlier command is still in flight or
  /// was lost; this command must wait/retry after the gap is filled,
  /// never be resubmitted with a new idempotency key.
  serverAhead,

  /// The exact same idempotency key was already processed — the cached
  /// server result is authoritative; no new effect happened.
  idempotencyReplay,

  /// Something automatic reconciliation cannot safely resolve on its
  /// own (a conflicting replay under the same idempotency key, or an
  /// unrecognized/internal failure) — spec section 6: "user-visible
  /// conflict state when automatic reconciliation is unsafe."
  conflict,
}

@immutable
class ReconciliationResult {
  const ReconciliationResult(
    this.outcome, {
    this.reasonCode,
    this.requiresUserAttention = false,
  });

  final ReconciliationOutcome outcome;
  final String? reasonCode;
  final bool requiresUserAttention;

  @override
  String toString() =>
      'ReconciliationResult($outcome, reasonCode: $reasonCode, '
      'requiresUserAttention: $requiresUserAttention)';
}

/// Deterministic reconciliation for the four commands whose server
/// response is a bare accept/reject verdict (accept, start, record-
/// progress, cancel) — [ServerValidationStatus] plus, on failure, the
/// stable error code the Edge Function returned. `submit-mission`'s
/// richer reward-bearing response goes through
/// [MissionSubmissionReconciliation] instead, since it has real payload
/// (XP/achievements/score) to merge on success, not just a verdict.
abstract final class MissionCommandReconciliation {
  static const _conflictCodes = {'idempotency_conflict', 'internal_error'};
  static const _staleCodes = {'stale_sequence'};
  static const _serverAheadCodes = {'out_of_order'};
  static const _replayCodes = {'duplicate_command'};

  /// [errorCode] is non-null only when the call failed before producing
  /// a normal [ServerValidationStatus] response (see
  /// `EdgeFunctionCallFailure.errorCode`) — a `null` [errorCode] means
  /// [serverStatus] is a genuine, well-formed server verdict.
  static ReconciliationResult reconcile({
    required ServerValidationStatus? serverStatus,
    String? errorCode,
  }) {
    if (errorCode != null) {
      if (_conflictCodes.contains(errorCode)) {
        return ReconciliationResult(
          ReconciliationOutcome.conflict,
          reasonCode: errorCode,
          requiresUserAttention: true,
        );
      }
      if (_staleCodes.contains(errorCode)) {
        return ReconciliationResult(
          ReconciliationOutcome.staleSequence,
          reasonCode: errorCode,
        );
      }
      if (_serverAheadCodes.contains(errorCode)) {
        return ReconciliationResult(
          ReconciliationOutcome.serverAhead,
          reasonCode: errorCode,
        );
      }
      if (_replayCodes.contains(errorCode)) {
        return ReconciliationResult(
          ReconciliationOutcome.idempotencyReplay,
          reasonCode: errorCode,
        );
      }
      // unauthenticated, forbidden, invalid_payload,
      // forbidden_authority_field, mission_not_found, invalid_transition
      // — all a clean rejection, nothing provisional to keep.
      return ReconciliationResult(
        ReconciliationOutcome.rejectedByServer,
        reasonCode: errorCode,
      );
    }

    return switch (serverStatus) {
      ServerValidationStatus.accepted => const ReconciliationResult(
        ReconciliationOutcome.accepted,
      ),
      ServerValidationStatus.rejected => const ReconciliationResult(
        ReconciliationOutcome.rejectedByServer,
      ),
      // `pending` is not a terminal verdict this phase's Edge Functions
      // ever return, but a well-formed contract member all the same —
      // treated as unsafe to auto-resolve rather than silently ignored.
      ServerValidationStatus.pending || null => const ReconciliationResult(
        ReconciliationOutcome.conflict,
        requiresUserAttention: true,
      ),
    };
  }
}

/// Reconciliation specifically for `submit-mission`'s response, which —
/// unlike the other four commands — carries real reward data on
/// success. [MissionSubmissionOutcome.reward] is only ever non-null when
/// [MissionCommandReconciliation.reconcile] on the same response would
/// have produced [ReconciliationOutcome.accepted] or [exactMatch] — this
/// type exists so callers can't accidentally read reward data off a
/// rejected/conflicted result.
@immutable
class MissionSubmissionOutcome {
  const MissionSubmissionOutcome({required this.base, this.reward});

  final ReconciliationResult base;
  final ConfirmedMissionReward? reward;
}

@immutable
class ConfirmedMissionReward {
  const ConfirmedMissionReward({
    required this.confirmedXpReward,
    required this.confirmedTotalXp,
    required this.previousLevel,
    required this.newLevel,
    required this.achievementUpdates,
    required this.competitionScoreUpdate,
  });

  final int confirmedXpReward;
  final int confirmedTotalXp;
  final int previousLevel;
  final int newLevel;
  final List<String> achievementUpdates;
  final double competitionScoreUpdate;
}

abstract final class MissionSubmissionReconciliation {
  static MissionSubmissionOutcome reconcile({
    required ServerValidationStatus? serverStatus,
    String? errorCode,
    ConfirmedMissionReward? reward,
  }) {
    final base = MissionCommandReconciliation.reconcile(
      serverStatus: serverStatus,
      errorCode: errorCode,
    );
    final isAccepted = base.outcome == ReconciliationOutcome.accepted;
    return MissionSubmissionOutcome(
      base: base,
      reward: isAccepted ? reward : null,
    );
  }
}
