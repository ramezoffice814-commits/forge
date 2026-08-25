/// User-selectable coaching tone (Roadmap Item 14 section 6) — a small,
/// closed set of *presentation* preferences, never an inferred
/// psychological trait. The user picks this explicitly; nothing in this
/// module ever derives it from behavior.
enum CoachingTone { calm, direct, energetic, strategic }

enum PreferredChallengeStyle { steady, ambitious, playful }

enum ExplanationDepth { brief, standard, detailed }

enum GoalFocus { consistency, variety, intensity, recovery }
