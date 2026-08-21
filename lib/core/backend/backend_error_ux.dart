import 'package:flutter/foundation.dart';

/// A safe, user-facing state derived from a stable backend error code
/// (spec section 19) — never a raw SQL error, stack trace, or internal
/// detail. Every variant maps to copy a screen can show directly; the
/// original [BackendErrorUxState.errorCode]/[message] are kept for
/// logging/debugging, never for direct display.
@immutable
sealed class BackendErrorUxState {
  const BackendErrorUxState(this.errorCode, this.message);

  final String? errorCode;
  final String message;
}

/// Local state is behind the server's — refetch/reconcile before
/// retrying (stale_sequence, out_of_order).
class RefreshAndReconcileUx extends BackendErrorUxState {
  const RefreshAndReconcileUx(super.errorCode, super.message);
}

/// A genuine sync conflict that automatic reconciliation can't resolve
/// (idempotency_conflict, duplicate_command, an unrecognized code) —
/// the user must be shown something, not silently retried.
class SyncConflictUx extends BackendErrorUxState {
  const SyncConflictUx(super.errorCode, super.message);
}

/// The mission's state changed underneath this action (invalid_transition,
/// mission_not_found) — the local mission view should refresh, not retry
/// the same command.
class MissionStateChangedUx extends BackendErrorUxState {
  const MissionStateChangedUx(super.errorCode, super.message);
}

/// The session is no longer valid — route to re-authentication
/// (unauthenticated).
class ReAuthRequiredUx extends BackendErrorUxState {
  const ReAuthRequiredUx(super.errorCode, super.message);
}

/// This exact action is not permitted for this user — never retried
/// automatically (forbidden, forbidden_authority_field).
class NotPermittedUx extends BackendErrorUxState {
  const NotPermittedUx(super.errorCode, super.message);
}

/// The submitted request was malformed — a client bug, not something a
/// retry fixes (invalid_payload).
class InvalidRequestUx extends BackendErrorUxState {
  const InvalidRequestUx(super.errorCode, super.message);
}

/// Progress doesn't meet the mission's completion criteria yet — the
/// mission stays open; this is an expected, non-alarming outcome, not a
/// failure (completion_requirements_not_met).
class KeepMissionOpenUx extends BackendErrorUxState {
  const KeepMissionOpenUx(super.errorCode, super.message);
}

/// A neutral, non-accusatory outcome — never explains *why* (spec
/// section 17: never expose internal anti-abuse detail) —
/// (integrity_rejected).
class IntegrityHoldUx extends BackendErrorUxState {
  const IntegrityHoldUx(super.errorCode, super.message);
}

/// Anything else, including a genuinely unexpected/internal failure or a
/// transport-level problem this module can't attribute to a known code —
/// a generic, retry-safe message (internal_error, unattributed failures).
class RetrySafeGenericUx extends BackendErrorUxState {
  const RetrySafeGenericUx(super.errorCode, super.message);
}

/// Maps a stable backend error code (see `supabase/functions/_shared/
/// errors.ts`) to the safe UX state a screen should render. `errorCode`
/// is `null` for a transport-level failure this app never got a coded
/// response for at all (timeout, connection loss, malformed response) —
/// treated the same as `internal_error`: retry-safe, generic, never
/// alarming, since the actual command may or may not have reached the
/// server (see spec section 20 — the caller is expected to retry with
/// the *same* idempotency key, which this state doesn't need to know
/// about itself).
BackendErrorUxState mapBackendErrorToUx(String? errorCode, String message) {
  return switch (errorCode) {
    'stale_sequence' ||
    'out_of_order' => RefreshAndReconcileUx(errorCode, message),
    'idempotency_conflict' ||
    'duplicate_command' => SyncConflictUx(errorCode, message),
    'invalid_transition' ||
    'mission_not_found' => MissionStateChangedUx(errorCode, message),
    'unauthenticated' => ReAuthRequiredUx(errorCode, message),
    'forbidden' ||
    'forbidden_authority_field' => NotPermittedUx(errorCode, message),
    'invalid_payload' => InvalidRequestUx(errorCode, message),
    'completion_requirements_not_met' => KeepMissionOpenUx(errorCode, message),
    'integrity_rejected' => IntegrityHoldUx(errorCode, message),
    _ => RetrySafeGenericUx(errorCode, message),
  };
}

/// Fixed, safe copy for each UX state — a screen may use this directly
/// or its own localized strings keyed by the state's runtime type; this
/// exists so there is always at least one non-alarming, non-technical
/// default that never leaks [BackendErrorUxState.message] (which may
/// originate from a server string not meant for display verbatim).
String defaultBackendErrorCopy(BackendErrorUxState state) {
  return switch (state) {
    RefreshAndReconcileUx() => "Catching up with the server — one moment.",
    SyncConflictUx() =>
      "This action couldn't be automatically synced. Please review and retry.",
    MissionStateChangedUx() => "This mission's state changed — refreshing.",
    ReAuthRequiredUx() => "Please sign in again to continue.",
    NotPermittedUx() => "This action isn't permitted.",
    InvalidRequestUx() => "Something went wrong with that request.",
    KeepMissionOpenUx() => "Not quite there yet — keep going!",
    IntegrityHoldUx() => "Some activity is pending verification.",
    RetrySafeGenericUx() => "Something went wrong. You can safely try again.",
  };
}
