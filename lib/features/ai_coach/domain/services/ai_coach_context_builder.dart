import '../entities/ai_coach_context.dart';
import '../entities/ai_personalization_profile.dart';
import '../enums/ai_privacy_level.dart';

/// The one place an [AiCoachContext] is ever assembled (Roadmap Item 14
/// section 5) — deliberately a pure function over already-narrow, plain
/// values (never a raw `MissionAggregate`/`UserProgressionProfile`/
/// `CompetitiveScoreEvaluation`), so there is no path into this class
/// that could accidentally carry a forbidden field along with it. The
/// presentation-layer provider that calls this is responsible only for
/// reading each already-public value off the relevant existing state and
/// handing it here by name — it can't pass through anything this
/// function's signature doesn't ask for.
///
/// [AiPrivacyLevel.limitedContext] deliberately omits progression/
/// competition/behavioral fields — [AiCoachTask.weeklyRecap] and
/// [AiCoachTask.coachChat] need more than that level provides, so
/// callers must check [supports] before dispatching those tasks.
abstract final class AiCoachContextBuilder {
  static const int _maxUserMessageLength = 500;

  static AiCoachContext build({
    required AiPrivacyLevel privacyLevel,
    required String displayName,
    String? currentMissionTitle,
    String? currentMissionCategory,
    String? currentMissionDifficulty,
    int availableMinutesToday = 20,
    int recentCompletionRatePercent = 0,
    int activeDaysThisWeek = 0,
    int currentLevel = 1,
    String currentTitle = '',
    String? currentLeagueName,
    List<String> recentCategoryUsage = const [],
    String consistencySummary = '',
    bool isRecoveryMode = false,
    AiPersonalizationProfile personalization = const AiPersonalizationProfile(),
    String? userMessage,
  }) {
    final isLimited = privacyLevel == AiPrivacyLevel.limitedContext;

    return AiCoachContext(
      displayName: displayName,
      currentMissionTitle: currentMissionTitle,
      currentMissionCategory: currentMissionCategory,
      currentMissionDifficulty: currentMissionDifficulty,
      availableMinutesToday: availableMinutesToday,
      // Progression/behavioral aggregates are zeroed out (not merely
      // hidden in the UI) under limitedContext — the field genuinely
      // never carries the real value into a request at that level.
      recentCompletionRatePercent: isLimited ? 0 : recentCompletionRatePercent,
      activeDaysThisWeek: isLimited ? 0 : activeDaysThisWeek,
      currentLevel: isLimited ? 1 : currentLevel,
      currentTitle: isLimited ? '' : currentTitle,
      currentLeagueName: isLimited ? null : currentLeagueName,
      recentCategoryUsage: isLimited ? const [] : recentCategoryUsage,
      consistencySummary: isLimited ? '' : consistencySummary,
      isRecoveryMode: isRecoveryMode,
      preferredCategories: personalization.preferredCategories,
      dislikedCategories: personalization.dislikedCategories,
      goalFocusLabel: personalization.goalFocus?.name,
      coachingTone: personalization.coachingTone,
      userMessage: _truncate(userMessage, _maxUserMessageLength),
    );
  }

  /// Whether [privacyLevel] carries enough context for [task] to be
  /// worth attempting at all — a caller should route straight to the
  /// deterministic fallback instead of making a request that would
  /// obviously read as generic (spec section 23's "AI disabled: Forge
  /// remains fully functional" extends to "AI severely limited" too).
  static bool supports(
    AiPrivacyLevel privacyLevel, {
    required bool needsProgressionContext,
  }) {
    if (privacyLevel == AiPrivacyLevel.disabled) return false;
    if (privacyLevel == AiPrivacyLevel.limitedContext &&
        needsProgressionContext) {
      return false;
    }
    return true;
  }

  static String? _truncate(String? value, int maxLength) {
    if (value == null) return null;
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
