/// Who/what produced an event — required on every event so a future
/// server can reason about trust (a `userAction` event is a claim the
/// server should verify; a `migration` event is backfilled data, never
/// re-verified the same way).
enum MissionEventSource {
  userAction,
  system,
  localValidation,
  futureServer,
  migration,
}

enum MissionEventType {
  assigned,
  viewed,
  accepted,
  started,
  progressUpdated,
  paused,
  resumed,
  submitted,
  validationPassed,
  validationFailed,
  completed,
  completionUndone,
  rejected,
  easierRequested,
  categoryChangeRequested,
  abandoned,
  expired,
  syncQueued,
  syncConfirmed,
  syncFailed,
}
