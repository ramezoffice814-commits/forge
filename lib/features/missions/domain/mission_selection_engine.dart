import 'entities/mission_candidate_score.dart';
import 'entities/mission_catalog_validator.dart';
import 'entities/mission_definition.dart';
import 'entities/mission_selection_request.dart';
import 'entities/mission_selection_result.dart';
import 'entities/user_discipline_profile.dart';
import 'enums/mission_category.dart';
import 'enums/mission_difficulty_level.dart';
import 'policies/adaptive_difficulty_policy.dart';
import 'policies/mission_safety_policy.dart';
import 'policies/mission_variety_policy.dart';
import 'policies/personalization_scorer.dart';
import 'policies/recovery_mission_policy.dart';
import 'policies/time_budget_policy.dart';
import 'repositories/mission_catalog_repository.dart';

typedef _Candidate = ({
  MissionDefinition definition,
  MissionDifficultyLevel resolvedDifficulty,
  int resolvedDuration,
  DifficultyResolution difficultyResolution,
});

typedef _ScoredCandidate = ({
  _Candidate candidate,
  MissionCandidateScore score,
});

/// The deterministic brain of Forge: given the same catalog, profile,
/// history, and date, always produces the same result. No AI, no
/// unseeded randomness — see `_tieBreakSeed` for how ties are broken
/// reproducibly instead.
///
/// Pipeline: active-catalog filter → hard eligibility (category/safety/
/// variety/time) → personalization scoring on survivors → deterministic
/// tie-break → fallback chain if nothing survives.
abstract final class MissionSelectionEngine {
  static const engineVersion = '1.0.0';

  static MissionSelectionResult select(MissionSelectionRequest request) {
    final now = request.currentDateTime;
    final profile = request.profile;
    final history = request.history;

    final recovery = RecoveryMissionPolicy.resolve(
      profile: profile,
      history: history,
      currentDateTime: now,
      override: request.recoveryOverride,
    );

    final activeCatalog = request.catalog
        .where((m) => m.active && MissionCatalogValidator.isValid(m))
        .toList();

    final rejected = <RejectedCandidate>[];
    final survivors = <_Candidate>[];

    for (final definition in activeCatalog) {
      final rejection = _hardFilter(
        definition: definition,
        request: request,
        recoveryActive: recovery.active,
        now: now,
      );
      if (rejection != null) {
        rejected.add(rejection);
        continue;
      }

      final difficultyResolution = AdaptiveDifficultyPolicy.resolve(
        category: definition.category,
        profile: profile,
        history: history,
        recoveryActive: recovery.active,
      );

      final safety = MissionSafetyPolicy.evaluate(
        mission: definition,
        profile: profile,
        recoveryActive: recovery.active,
      );
      var resolvedDifficulty =
          safety.modifiedDifficulty ?? difficultyResolution.resolvedDifficulty;
      if (resolvedDifficulty.index < definition.minimumDifficulty.index) {
        resolvedDifficulty = definition.minimumDifficulty;
      }
      if (resolvedDifficulty.index > definition.maximumDifficulty.index) {
        resolvedDifficulty = definition.maximumDifficulty;
      }

      final requestedDuration = recovery.active
          ? (request.requestedDuration ??
                    RecoveryMissionPolicy.recoveryDurationCapMinutes)
                .clamp(0, RecoveryMissionPolicy.recoveryDurationCapMinutes)
          : request.requestedDuration;
      final time = TimeBudgetPolicy.resolve(
        mission: definition,
        availableMinutesToday: profile.availableMinutesToday,
        requestedDuration: requestedDuration,
      );
      if (!time.fits) {
        rejected.add(
          RejectedCandidate(
            missionId: definition.id,
            reasonCodes: const ['exceedsTimeLimit'],
          ),
        );
        continue;
      }

      survivors.add((
        definition: definition,
        resolvedDifficulty: resolvedDifficulty,
        resolvedDuration: time.resolvedMinutes,
        difficultyResolution: difficultyResolution,
      ));
    }

    if (survivors.isEmpty) {
      return _fallback(
        request: request,
        activeCatalog: activeCatalog,
        recoveryActive: recovery.active,
        recoveryReason: recovery.reason,
        rejected: rejected,
      );
    }

    final scored = <_ScoredCandidate>[
      for (final candidate in survivors)
        (
          candidate: candidate,
          score: PersonalizationScorer.score(
            mission: candidate.definition,
            profile: profile,
            history: history,
            catalog: activeCatalog,
            resolvedDifficulty: candidate.resolvedDifficulty,
            resolvedDuration: candidate.resolvedDuration,
            recoveryActive: recovery.active,
            currentDateTime: now,
          ),
        ),
    ];

    scored.sort((a, b) => b.score.total.compareTo(a.score.total));
    final topScore = scored.first.score.total;
    final topTier =
        scored.where((s) => (topScore - s.score.total).abs() < 0.0001).toList()
          ..sort(
            (a, b) =>
                a.candidate.definition.id.compareTo(b.candidate.definition.id),
          );

    final chosen = topTier.length == 1
        ? topTier.first
        : topTier[_tieBreakSeed(profile.userId, now) % topTier.length];

    // A mission denied specifically for conflicting with a declared
    // restriction, but which names an alternative that *did* survive and
    // got picked, means the user effectively got that accessible swap.
    final accessibilityAlternativeIds = <String>{
      for (final r in rejected)
        if (r.reasonCodes.contains('conflictsWithUserRestriction'))
          ...activeCatalog
              .where(
                (m) =>
                    m.id == r.missionId && m.accessibilityAlternativeId != null,
              )
              .map((m) => m.accessibilityAlternativeId!),
    };
    final usedAccessibilityAlternative = accessibilityAlternativeIds.contains(
      chosen.candidate.definition.id,
    );

    return MissionSelectionResult(
      selectedMission: chosen.candidate.definition,
      resolvedDifficulty: chosen.candidate.resolvedDifficulty,
      resolvedDuration: chosen.candidate.resolvedDuration,
      selectionReasons: _buildReasons(
        chosen: chosen,
        profile: profile,
        recoveryActive: recovery.active,
        recoveryReason: recovery.reason,
        request: request,
        usedAccessibilityAlternative: usedAccessibilityAlternative,
      ),
      recoveryApplied: recovery.active,
      accessibilityAlternativeUsed: usedAccessibilityAlternative,
      fallbackUsed: false,
      confidence: chosen.candidate.difficultyResolution.confidence,
      engineVersion: engineVersion,
      rejectedCandidatesSummary: rejected,
      safetyChecks: const ['allowed'],
    );
  }

  static RejectedCandidate? _hardFilter({
    required MissionDefinition definition,
    required MissionSelectionRequest request,
    required bool recoveryActive,
    required DateTime now,
  }) {
    if (request.excludedMissionIds.contains(definition.id)) {
      return RejectedCandidate(
        missionId: definition.id,
        reasonCodes: const ['excludedThisRound'],
      );
    }
    if (request.requestedCategory != null &&
        definition.category != request.requestedCategory) {
      return RejectedCandidate(
        missionId: definition.id,
        reasonCodes: const ['wrongCategory'],
      );
    }

    final safety = MissionSafetyPolicy.evaluate(
      mission: definition,
      profile: request.profile,
      recoveryActive: recoveryActive,
    );
    if (safety.isDenied) {
      return RejectedCandidate(
        missionId: definition.id,
        reasonCodes: safety.reasonCodes,
      );
    }

    if (MissionVarietyPolicy.isWithinCooldown(
      definition,
      request.history,
      now,
    )) {
      return RejectedCandidate(
        missionId: definition.id,
        reasonCodes: const ['repeatCooldownActive'],
      );
    }
    if (MissionVarietyPolicy.exceedsWeeklyLimit(
      definition,
      request.history,
      now,
    )) {
      return RejectedCandidate(
        missionId: definition.id,
        reasonCodes: const ['weeklyOccurrenceLimitReached'],
      );
    }

    return null;
  }

  static List<String> _buildReasons({
    required _ScoredCandidate chosen,
    required UserDisciplineProfile profile,
    required bool recoveryActive,
    required String? recoveryReason,
    required MissionSelectionRequest request,
    required bool usedAccessibilityAlternative,
  }) {
    final definition = chosen.candidate.definition;
    final reasons = <String>[];

    if (recoveryActive) {
      reasons.add(recoveryReason ?? 'Selected as a recovery-safe mission.');
    }
    if (usedAccessibilityAlternative) {
      reasons.add('Used an accessibility-friendly alternative for your needs.');
    }
    if (request.requestedCategory != null) {
      reasons.add(
        'Matches your requested ${missionCategoryLabel(definition.category)} category.',
      );
    } else if (profile.preferredCategories.contains(definition.category)) {
      reasons.add(
        'Matches your preferred ${missionCategoryLabel(definition.category)} category.',
      );
    }
    reasons.add(
      'Fits your ${chosen.candidate.resolvedDuration}-minute availability.',
    );
    if (chosen.candidate.difficultyResolution.reasonCodes.contains(
      'stableSuccessIncrease',
    )) {
      reasons.add('Difficulty was increased after consistent recent success.');
    }
    if (chosen.candidate.difficultyResolution.reasonCodes.contains(
          'repeatedMissesDecrease',
        ) ||
        chosen.candidate.difficultyResolution.reasonCodes.contains(
          'highEffortDecrease',
        )) {
      reasons.add('Difficulty was reduced to help rebuild momentum.');
    }
    if (chosen.score.factorScores['variety'] != null &&
        chosen.score.factorScores['variety']! > 0.8) {
      reasons.add('Not recently repeated.');
    }

    return reasons;
  }

  static MissionSelectionResult _fallback({
    required MissionSelectionRequest request,
    required List<MissionDefinition> activeCatalog,
    required bool recoveryActive,
    required String? recoveryReason,
    required List<RejectedCandidate> rejected,
  }) {
    final universal =
        activeCatalog
            .where((m) => m.tags.contains('universalFallback'))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    if (universal.isEmpty) {
      throw const MissionCatalogException(
        'No eligible mission and no universal fallback available in the '
        'catalog — the catalog itself is unavailable or empty.',
      );
    }

    final pick =
        universal[_tieBreakSeed(
              request.profile.userId,
              request.currentDateTime,
            ) %
            universal.length];
    final time = TimeBudgetPolicy.resolve(
      mission: pick,
      availableMinutesToday: request.profile.availableMinutesToday,
    );

    return MissionSelectionResult(
      selectedMission: pick,
      resolvedDifficulty: pick.baseDifficulty,
      resolvedDuration: time.resolvedMinutes,
      selectionReasons: [
        if (recoveryActive)
          recoveryReason ?? 'Selected as a recovery-safe mission.',
        'No ideal match was available, so a safe universal mission was used instead.',
      ],
      recoveryApplied: recoveryActive,
      fallbackUsed: true,
      fallbackReason: 'noEligibleCandidates',
      confidence: 0.3,
      engineVersion: engineVersion,
      rejectedCandidatesSummary: rejected,
      safetyChecks: const ['allowed'],
    );
  }

  /// Stable, reproducible hash of user + calendar date — used only to break
  /// ties among equally-scored top candidates. Deliberately not
  /// `dart:math`'s `Random` (whose algorithm isn't a documented contract);
  /// a plain string hash is auditable and stable across Dart versions.
  static int _tieBreakSeed(String userId, DateTime date) {
    final key = '$userId|${date.year}-${date.month}-${date.day}';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
