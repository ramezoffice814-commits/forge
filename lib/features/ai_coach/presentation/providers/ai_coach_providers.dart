import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../../core/backend/backend_mode.dart';
import '../../../../core/backend/backend_providers.dart';
import '../../../../core/backend/supabase_edge_functions_client.dart';
import '../../../auth/presentation/auth_state.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../data/ai_coach_cache_store.dart';
import '../../data/ai_coach_client.dart';
import '../../data/ai_coach_repository_impl.dart';
import '../../data/ai_privacy_preference_store.dart';
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

/// Loads the persisted privacy choice, if any, and applies it to
/// [aiPrivacyLevelProvider] — `ref.watch`ed from [ForgeApp] at the app
/// root, so a restart restores whatever the user last chose, without
/// turning every other read of [aiPrivacyLevelProvider] into an async
/// one. A `null` result (nothing saved yet for this user) leaves the
/// provider's own default ([AiPrivacyLevel.limitedContext]) untouched.
///
/// Deliberately re-runs on every auth status change (via the
/// `ref.watch` below), not just once at startup — found during Roadmap
/// Item 16's account-switch audit: without this, signing out and a
/// second account signing in on the same running app (no restart)
/// would leave whatever level the first account left in memory, and a
/// save would persist under one shared key regardless of who was
/// actually signed in. Resets to the safe default while signed out, and
/// reloads fresh for whichever user just authenticated.
final aiPrivacyBootstrapProvider = FutureProvider<void>((ref) async {
  final authStatus = ref.watch(
    authStateNotifierProvider.select((s) => s.status),
  );
  // Riverpod forbids a provider from writing to another provider while
  // still synchronously building itself — without this yield, a status
  // change straight to unauthenticated (e.g. sign-out) hits "Providers
  // are not allowed to modify other providers during their
  // initialization" the moment this rebuilds.
  await Future<void>.value();
  if (authStatus != AuthStatus.authenticated) {
    ref.read(aiPrivacyLevelProvider.notifier).state =
        AiPrivacyLevel.limitedContext;
    return;
  }
  final userId = ref.read(authStateNotifierProvider).session!.user.id;
  final saved = await ref.read(aiPrivacyPreferenceStoreProvider).load(userId);
  ref.read(aiPrivacyLevelProvider.notifier).state =
      saved ?? AiPrivacyLevel.limitedContext;
});

/// The one place [aiPrivacyLevelProvider] is ever changed by user action
/// — updates the in-memory value immediately (so the UI reacts without
/// waiting on a write) and persists it via [AiPrivacyPreferenceStore]
/// under the currently-authenticated user's own key.
Future<void> setAiPrivacyLevel(WidgetRef ref, AiPrivacyLevel level) async {
  ref.read(aiPrivacyLevelProvider.notifier).state = level;
  final userId = ref.read(authStateNotifierProvider).session?.user.id;
  // Only reachable from an authenticated-only screen in practice, but
  // guarded rather than assumed — a change with nobody signed in has
  // nothing to persist under.
  if (userId == null) return;
  await ref.read(aiPrivacyPreferenceStoreProvider).save(userId, level);
}

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
