/// `requiresCaution` missions get extra scrutiny from [MissionSafetyPolicy]
/// (stricter duration/intensity checks, always excluded during recovery
/// mode) — physical/sleep-adjacent categories mostly fall here. `standard`
/// missions still pass through every safety check, just without the extra
/// margin.
enum SafetyClassification { standard, requiresCaution }
