import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ai_coach_response.dart';
import 'ai_coach_providers.dart';

/// Identity for a single mission's AI insight request — equality is by
/// value so Riverpod's family caching naturally dedupes repeated builds
/// for the same mission without a separate memoization layer.
class MissionAiInsightParams {
  const MissionAiInsightParams({
    required this.displayName,
    required this.missionTitle,
    required this.missionCategory,
    required this.missionDifficulty,
  });

  final String displayName;
  final String missionTitle;
  final String missionCategory;
  final String missionDifficulty;

  @override
  bool operator ==(Object other) =>
      other is MissionAiInsightParams &&
      other.displayName == displayName &&
      other.missionTitle == missionTitle &&
      other.missionCategory == missionCategory &&
      other.missionDifficulty == missionDifficulty;

  @override
  int get hashCode => Object.hash(
    displayName,
    missionTitle,
    missionCategory,
    missionDifficulty,
  );
}

/// Roadmap Item 14 section 20 — the mission explanation panel's data
/// source. [GetMissionExplanationUseCase] never throws (the underlying
/// repository always resolves to either a real or a fallback response),
/// so this provider's only failure mode is a genuine bug, not a normal
/// "AI unavailable" case — that case is already a successful, safe
/// [AiCoachResponse] from [AiCoachFallbackTemplates].
final missionAiInsightProvider = FutureProvider.autoDispose
    .family<AiCoachResponse, MissionAiInsightParams>((ref, params) {
      final privacyLevel = ref.watch(aiPrivacyLevelProvider);
      final personalization = ref.watch(aiPersonalizationProfileProvider);
      final useCase = ref.watch(getMissionExplanationUseCaseProvider);
      return useCase(
        privacyLevel: privacyLevel,
        displayName: params.displayName,
        missionTitle: params.missionTitle,
        missionCategory: params.missionCategory,
        missionDifficulty: params.missionDifficulty,
        personalization: personalization,
      );
    });
