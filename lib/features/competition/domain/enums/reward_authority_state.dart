/// Mirrors the missions module's `MissionRewardState` philosophy: this
/// phase never has the authority to mint a `confirmed` competitive score,
/// only ever a local preview pending a future backend round trip.
enum RewardAuthorityState { localPreviewOnly, pendingServerConfirmation }
