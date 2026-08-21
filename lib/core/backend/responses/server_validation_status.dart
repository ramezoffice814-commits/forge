/// A backend response's top-level verdict on a command.
enum ServerValidationStatus { accepted, rejected, pending }

/// A submission-specific integrity verdict — mirrors the neutral,
/// non-accusatory framing already used by the competition module's own
/// integrity states (never surfaced to the user as an accusation).
enum ServerIntegrityStatus { clean, warning, rejected }

enum MissionServerState { completed, rejected, pendingReview }
