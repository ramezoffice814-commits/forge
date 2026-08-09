/// A coarse, explainable quality tag for a completion (e.g. derived from
/// proof/validation signals upstream) — never a precision score, so the
/// quality factor it drives stays easy to state in plain language.
enum CompletionQuality { low, standard, high }
