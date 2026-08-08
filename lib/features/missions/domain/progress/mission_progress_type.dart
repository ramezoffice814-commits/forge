/// The ten progress models this phase supports. `focusSession` from the
/// spec's type list is deliberately not a distinct case here — it's
/// represented as a [MissionProgressType.timer] (identical shape: an
/// accumulated vs. target duration); the spec's own control-widget list
/// omits a separate focus-session control too, so no UI or policy
/// branch is lost by folding it in.
enum MissionProgressType {
  binary,
  counter,
  timer,
  checklist,
  percentage,
  quantity,
  reflection,
  reading,
  codingSession,
  hydration,
}
