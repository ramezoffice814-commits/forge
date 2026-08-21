/// The client/server trust boundary for Forge's competitive systems.
///
/// This file has no runtime behavior — it is the single place this rule
/// is written down, so every future PR touching XP, ranking, or
/// achievements can be checked against it directly instead of relying on
/// tribal knowledge.
///
/// ---------------------------------------------------------------------
/// THE RULE
/// ---------------------------------------------------------------------
/// The client MAY REQUEST an action (accept a mission, submit progress,
/// submit completion). The client MAY NEVER AUTHORIZE the reward for that
/// action. Authorization is the sole responsibility of a backend
/// (currently mocked via [BackendClient]/[MockBackendClient]; a real
/// Supabase adapter arrives in a later phase behind the same interface —
/// see `supabase_backend_client.dart`).
///
/// Concretely: nothing in `core/backend/commands/` may carry a computed
/// reward field (see `BackendCommand.forbiddenClientFields`). Only
/// `core/backend/responses/` types carry rewards, and only as
/// [AuthoritativeValue]s obtained through an actual [RawBackendResponse]
/// (see that class's constructor, which is private to its own file).
///
/// ---------------------------------------------------------------------
/// DATA CLASSIFICATION
/// ---------------------------------------------------------------------
/// CLIENT OWNED — the client is the source of truth; no server
/// confirmation is needed or meaningful:
///   - UI preferences, theme, accessibility settings
///   - draft/in-progress form state
///   - local notification scheduling
///   - `ProfileVisibilitySettings` (a user's own privacy choice)
///
/// PROVISIONAL — computed locally today as a preview; a future backend
/// independently recomputes and may produce a different final number.
/// Always wrapped in [ProvisionalValue], always labeled as a preview in
/// UI copy ("(preview)", "not yet confirmed"):
///   - `XpRewardEvaluation` / `UserProgressionProfile.provisionalXp`
///   - `CompetitiveScoreEvaluation` / `WeeklyCompetitionScore.cappedScore`
///   - `LeagueMovementPreview` / `RookiePlacementResult`
///   - `SeasonScore`
///
/// SERVER AUTHORITATIVE — only a genuine [RawBackendResponse] can
/// produce these; the client can request them but never mint them itself:
///   - confirmed XP reward (`MissionSubmissionServerResult.confirmedXpReward`)
///   - confirmed mission completion state
///   - achievement unlocks
///   - competitive score confirmation
///   - league placement / promotion / demotion
///   - season results
///   - integrity verdicts (`ServerIntegrityStatus`)
///
/// ---------------------------------------------------------------------
/// WHY THIS MATTERS
/// ---------------------------------------------------------------------
/// Everything under PROVISIONAL already exists in the app (progression,
/// competition) and is deliberately, honestly labeled as non-final in
/// both code (`provisionalOnly` fields) and UI copy. Phase 10A does not
/// change that — it builds the contracts a future phase will use to
/// eventually make the SERVER AUTHORITATIVE column real. Until then, nothing
/// under SERVER AUTHORITATIVE is actually backed by a real network call —
/// see `MockBackendClient`'s own doc comment.
library;
