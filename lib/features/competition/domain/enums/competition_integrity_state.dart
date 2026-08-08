/// Shared by both a single completion's pre-tagged integrity state
/// ([CompetitiveCompletionSummary.eventIntegrityState]) and a fuller
/// [CompetitionIntegrityEvaluation]'s aggregate verdict — `excluded` means
/// "scores zero, quietly", never an accusation surfaced to the user (UI
/// copy stays neutral: "some activity is pending verification").
enum CompetitionIntegrityState { clean, warning, excluded }
