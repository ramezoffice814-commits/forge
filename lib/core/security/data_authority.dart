/// How trustworthy a value is, for anything that will eventually need
/// server confirmation (XP, competitive score, league placement, season
/// results, achievement unlocks). See `trust_boundary.dart` for the full
/// policy and `authoritative_value.dart` for the type that carries this.
enum DataAuthority {
  /// Exists only on this device, never sent anywhere and never intended
  /// to be — e.g. a UI-only draft value.
  localOnly,

  /// Computed locally as a preview/estimate. Displayable, but must never
  /// be treated as final — the same value a future server calculation
  /// arrives at may differ.
  provisional,

  /// Received from an actual [BackendClient] response. The only level
  /// that may be treated as final.
  serverConfirmed,
}
