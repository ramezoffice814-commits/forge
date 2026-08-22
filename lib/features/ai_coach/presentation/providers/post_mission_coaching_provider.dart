import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ai_coach_response.dart';
import 'ai_coach_providers.dart';

class PostMissionCoachingParams {
  const PostMissionCoachingParams({
    required this.displayName,
    required this.missionTitle,
    required this.missionCategory,
    required this.consistencySummary,
  });

  final String displayName;
  final String missionTitle;
  final String missionCategory;
  final String consistencySummary;

  @override
  bool operator ==(Object other) =>
      other is PostMissionCoachingParams &&
      other.displayName == displayName &&
      other.missionTitle == missionTitle &&
      other.missionCategory == missionCategory &&
      other.consistencySummary == consistencySummary;

  @override
  int get hashCode => Object.hash(
    displayName,
    missionTitle,
    missionCategory,
    consistencySummary,
  );
}

/// Roadmap Item 14 section 20 — a brief shown once, right after a
/// mission's server-confirmed completion. `autoDispose` is deliberate:
/// there is no reason to keep this cached once the completion screen
/// that triggered it is gone.
final postMissionCoachingProvider = FutureProvider.autoDispose
    .family<AiCoachResponse, PostMissionCoachingParams>((ref, params) {
      final privacyLevel = ref.watch(aiPrivacyLevelProvider);
      final personalization = ref.watch(aiPersonalizationProfileProvider);
      final useCase = ref.watch(getPostMissionCoachingUseCaseProvider);
      return useCase(
        privacyLevel: privacyLevel,
        displayName: params.displayName,
        missionTitle: params.missionTitle,
        missionCategory: params.missionCategory,
        consistencySummary: params.consistencySummary,
        personalization: personalization,
      );
    });
