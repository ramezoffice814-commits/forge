/// How trustworthy a [ResolvedMissionInstance]'s identity currently is —
/// spec section 3 of Roadmap Item 13C's "never silently substitute a local
/// id for a confirmed server id" requirement, made explicit at the type
/// level rather than left to convention.
enum MissionInstanceAuthority {
  /// Mock mode only — there is no backend to confirm anything against, so
  /// the locally-generated deterministic id is the only id that will ever
  /// exist for this mission.
  localOnly,

  /// Live/staging mode, but the authoritative server assignment hasn't
  /// been obtained yet (offline, in flight, or failed with nothing cached)
  /// — this instance's id is a local placeholder, not yet safe to submit
  /// against as if it were server-confirmed (spec section 8).
  provisionalPendingServer,

  /// Live/staging mode and the id genuinely came from the server's own
  /// `assignDailyMission` response (or a previously-cached one) — the only
  /// state in which mission commands may be sent using this id.
  serverConfirmed,
}
