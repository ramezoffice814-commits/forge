/// Whether a completion is trustworthy enough to score at all. This is
/// deliberately coarser than the missions module's validation-failure
/// reason codes — competition only needs to know "count it or don't",
/// never the underlying reason (that stays inside the missions module).
enum CompletionValidationState { valid, invalid, unverified }
