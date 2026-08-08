import 'package:flutter/foundation.dart';

import '../enums/data_confidence.dart';
import '../enums/mission_category.dart';
import '../enums/mission_difficulty_level.dart';

/// What the engine knows about the user's stated preferences and
/// constraints. Everything here is either onboarding input or an explicit
/// user action — never an inferred medical or psychological condition (see
/// the privacy trust boundary documented in `MissionSafetyPolicy`).
@immutable
class UserDisciplineProfile {
  const UserDisciplineProfile({
    required this.userId,
    this.selectedGoals = const {},
    this.preferredCategories = const {},
    this.avoidedCategories = const {},
    this.availableMinutesToday = 20,
    this.preferredMissionDuration,
    this.preferredDifficulty,
    this.fitnessSelfAssessment = FitnessSelfAssessment.moderate,
    this.accessibilityNeeds = const {},
    this.healthLimitations = const {},
    this.preferredActiveHours = const [],
    this.timezone = 'UTC',
    this.recoveryModeActive = false,
    this.manualIntensityCap,
    this.onboardingCompletedAt,
  });

  final String userId;
  final Set<String> selectedGoals;
  final Set<MissionCategory> preferredCategories;
  final Set<MissionCategory> avoidedCategories;

  final int availableMinutesToday;
  final int? preferredMissionDuration;
  final MissionDifficultyLevel? preferredDifficulty;
  final FitnessSelfAssessment fitnessSelfAssessment;

  /// User-declared tags only (e.g. `'knee_sensitive'`, `'low_vision'`) —
  /// never inferred. See `MissionDefinition.excludedConditions`.
  final Set<String> accessibilityNeeds;
  final Set<String> healthLimitations;

  /// Hours of day (0–23) the user says they're usually active.
  final List<int> preferredActiveHours;
  final String timezone;

  final bool recoveryModeActive;
  final MissionDifficultyLevel? manualIntensityCap;
  final DateTime? onboardingCompletedAt;

  UserDisciplineProfile copyWith({
    Set<String>? selectedGoals,
    Set<MissionCategory>? preferredCategories,
    Set<MissionCategory>? avoidedCategories,
    int? availableMinutesToday,
    int? preferredMissionDuration,
    MissionDifficultyLevel? preferredDifficulty,
    FitnessSelfAssessment? fitnessSelfAssessment,
    Set<String>? accessibilityNeeds,
    Set<String>? healthLimitations,
    List<int>? preferredActiveHours,
    String? timezone,
    bool? recoveryModeActive,
    MissionDifficultyLevel? manualIntensityCap,
    DateTime? onboardingCompletedAt,
  }) {
    return UserDisciplineProfile(
      userId: userId,
      selectedGoals: selectedGoals ?? this.selectedGoals,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      avoidedCategories: avoidedCategories ?? this.avoidedCategories,
      availableMinutesToday:
          availableMinutesToday ?? this.availableMinutesToday,
      preferredMissionDuration:
          preferredMissionDuration ?? this.preferredMissionDuration,
      preferredDifficulty: preferredDifficulty ?? this.preferredDifficulty,
      fitnessSelfAssessment:
          fitnessSelfAssessment ?? this.fitnessSelfAssessment,
      accessibilityNeeds: accessibilityNeeds ?? this.accessibilityNeeds,
      healthLimitations: healthLimitations ?? this.healthLimitations,
      preferredActiveHours: preferredActiveHours ?? this.preferredActiveHours,
      timezone: timezone ?? this.timezone,
      recoveryModeActive: recoveryModeActive ?? this.recoveryModeActive,
      manualIntensityCap: manualIntensityCap ?? this.manualIntensityCap,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
    );
  }
}
