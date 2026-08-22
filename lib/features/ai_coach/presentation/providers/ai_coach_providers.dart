import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../../core/backend/backend_mode.dart';
import '../../../../core/backend/backend_providers.dart';
import '../../../../core/backend/supabase_edge_functions_client.dart';
import '../../data/ai_coach_cache_store.dart';
import '../../data/ai_coach_client.dart';
import '../../data/ai_coach_repository_impl.dart';
import '../../data/mock/mock_ai_coach_client.dart';
import '../../data/supabase/supabase_ai_coach_client.dart';
import '../../domain/entities/ai_personalization_profile.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../../domain/repositories/ai_coach_repository.dart';
import '../../domain/usecases/get_daily_transmission_dialogue_usecase.dart';
import '../../domain/usecases/get_mission_explanation_usecase.dart';
import '../../domain/usecases/get_post_mission_coaching_usecase.dart';
import '../../domain/usecases/get_weekly_recap_usecase.dart';
import '../../domain/usecases/send_coach_chat_message_usecase.dart';

/// Defaults to [AiPrivacyLevel.limitedContext], not `fullContext` — this
/// app's other privacy-sensitive defaults (social profile visibility,
/// friends-only not public) are consistently the more private option
/// until a user explicitly opts into more; AI context follows the same
/// convention. Overridable in tests and once a real settings screen
/// exists to let the user change it (spec section 23).
final aiPrivacyLevelProvider = StateProvider<AiPrivacyLevel>((ref) {
  return AiPrivacyLevel.limitedContext;
});

final aiPersonalizationProfileProvider =
    StateProvider<AiPersonalizationProfile>((ref) {
      return const AiPersonalizationProfile();
    });

/// Mock in mock backend mode (spec section 3: "mock mode must remain
/// fully usable") and in live/staging mode alike *until* a real AI
/// provider is actually deployed to the `ai-coach` Edge Function — see
/// the Item 14 final report's provider-selection section for why no
/// production provider is wired yet. Swapping this to
/// `SupabaseAiCoachClient` end-to-end for a real provider is then a
/// one-line change here, not a rewrite.
final aiCoachClientProvider = Provider<AiCoachClient>((ref) {
  final mode = ref.watch(backendModeProvider);
  if (mode == BackendMode.mock) {
    return const MockAiCoachClient();
  }
  return SupabaseAiCoachClient(
    SupabaseEdgeFunctionsClient(supa.Supabase.instance.client),
  );
});

final aiCoachRepositoryProvider = Provider<AiCoachRepository>((ref) {
  return AiCoachRepositoryImpl(
    client: ref.watch(aiCoachClientProvider),
    cacheStore: ref.watch(aiCoachCacheStoreProvider),
    privacyLevel: () => ref.read(aiPrivacyLevelProvider),
  );
});

final getMissionExplanationUseCaseProvider =
    Provider<GetMissionExplanationUseCase>((ref) {
      return GetMissionExplanationUseCase(ref.watch(aiCoachRepositoryProvider));
    });

final getDailyTransmissionDialogueUseCaseProvider =
    Provider<GetDailyTransmissionDialogueUseCase>((ref) {
      return GetDailyTransmissionDialogueUseCase(
        ref.watch(aiCoachRepositoryProvider),
      );
    });

final getPostMissionCoachingUseCaseProvider =
    Provider<GetPostMissionCoachingUseCase>((ref) {
      return GetPostMissionCoachingUseCase(
        ref.watch(aiCoachRepositoryProvider),
      );
    });

final getWeeklyRecapUseCaseProvider = Provider<GetWeeklyRecapUseCase>((ref) {
  return GetWeeklyRecapUseCase(ref.watch(aiCoachRepositoryProvider));
});

final sendCoachChatMessageUseCaseProvider =
    Provider<SendCoachChatMessageUseCase>((ref) {
      return SendCoachChatMessageUseCase(ref.watch(aiCoachRepositoryProvider));
    });
