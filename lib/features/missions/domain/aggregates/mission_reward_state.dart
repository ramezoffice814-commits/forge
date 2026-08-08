/// Local, non-authoritative reward status. `confirmed`/`rejected` are
/// included for completeness of the model but nothing in this phase ever
/// sets them — only a future trusted server workflow can, which is exactly
/// the trust boundary this whole feature is built around.
enum MissionRewardState {
  none,
  pendingValidation,
  pendingServerConfirmation,
  confirmed,
  rejected,
}
