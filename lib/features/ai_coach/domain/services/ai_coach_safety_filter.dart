import '../entities/ai_coach_response.dart';

/// Application-level validation of AI output (Roadmap Item 14 section
/// 13) — a second, independent line of defense beyond prompting. Runs on
/// every response before it ever reaches a widget, whether it came from
/// the mock provider, a real provider, or (in tests) a hand-built
/// fixture. Deliberately simple pattern matching, not another AI call:
/// a safety filter that itself depends on the thing it's supposed to
/// backstop isn't a backstop.
abstract final class AiCoachSafetyFilter {
  /// Case-insensitive substring signals for each forbidden-behavior
  /// category (spec sections 9 and 13). Intentionally broad/blunt —
  /// false positives here just mean falling back to safe template copy,
  /// which is always an acceptable outcome; false negatives are not.
  static const List<String> _unsafeSignals = [
    // Secrets / system-prompt exposure.
    'system prompt',
    'my instructions are',
    'api key',
    'password',
    'service_role',
    'service role key',
    'cron secret',
    // Unsafe medical/extreme-exercise instruction.
    'ignore the pain',
    'push through the injury',
    'skip meals',
    'you don\'t need rest',
    'diagnos', // catches "diagnose"/"diagnosis"
    // Unsupported authority claims — the AI narrating as if it, not the
    // server, decided a reward-bearing outcome.
    'i have granted you',
    'i have awarded you',
    'your rank is now',
    'i\'ve updated your',
    'your xp has been',
  ];

  /// `true` if [response] must be discarded in favor of the fallback
  /// template — never partially shown or "cleaned up" in place. A
  /// response that trips this filter is not a formatting problem; it's
  /// exactly the class of output this module exists to prevent from
  /// reaching a user.
  static bool isUnsafe(AiCoachResponse response) {
    final haystack = [
      response.message,
      response.reasoningSummary ?? '',
    ].join(' ').toLowerCase();

    for (final signal in _unsafeSignals) {
      if (haystack.contains(signal)) return true;
    }
    return false;
  }
}
