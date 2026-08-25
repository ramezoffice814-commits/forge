import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../missions/presentation/providers/resolved_mission_instance_controller.dart';
import '../../domain/entities/ai_coach_response.dart';
import 'ai_coach_providers.dart';

/// Roadmap Item 14B — the mission explanation panel's data source.
/// Deliberately reads [resolvedMissionInstanceProvider] itself rather
/// than accepting mission title/category/difficulty as caller-supplied
/// parameters: that is Forge's one authoritative "today's mission"
/// (Roadmap Item 13C) — a caller passing its own copy of those facts
/// could theoretically drift from it, which this design makes
/// structurally impossible. [displayName] is the only true input,
/// since nothing mission-related can supply it.
///
/// [GetMissionExplanationUseCase] never throws (the underlying
/// repository always resolves to either a real or a fallback response),
/// so this provider's only failure mode is a genuine bug, not a normal
/// "AI unavailable" case — that case is already a successful, safe
/// [AiCoachResponse] from [AiCoachFallbackTemplates]. Resolves to `null`
/// when there is no authoritative mission yet (loading/empty) — the
/// widget renders nothing in that case, same as an empty
/// [MissionExplanationPanel].
final missionAiInsightProvider = FutureProvider.autoDispose
    .family<AiCoachResponse?, String>((ref, displayName) {
      final resolved = ref.watch(resolvedMissionInstanceProvider);
      if (resolved == null) return Future.value(null);

      final privacyLevel = ref.watch(aiPrivacyLevelProvider);
      final personalization = ref.watch(aiPersonalizationProfileProvider);
      final useCase = ref.watch(getMissionExplanationUseCaseProvider);
      return useCase(
        privacyLevel: privacyLevel,
        displayName: displayName,
        missionTitle: resolved.instance.title,
        missionCategory: resolved.instance.category.name,
        missionDifficulty: resolved.instance.resolvedDifficulty.name,
        personalization: personalization,
      );
    });
