import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_state_notifier.dart';
import '../../../competition/presentation/providers/competition_providers.dart';
import '../../../progression/presentation/providers/progression_providers.dart';
import '../../data/mock/mock_social_seeder.dart';
import '../../data/repositories/in_memory_social_repository.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/accept_friend_request_usecase.dart';
import '../../domain/usecases/get_activity_feed_usecase.dart';
import '../../domain/usecases/get_friends_usecase.dart';
import '../../domain/usecases/get_pending_requests_usecase.dart';
import '../../domain/usecases/get_public_profile_usecase.dart';
import '../../domain/usecases/reject_friend_request_usecase.dart';
import '../../domain/usecases/remove_friend_usecase.dart';
import '../../domain/usecases/send_friend_request_usecase.dart';
import '../../domain/usecases/set_profile_visibility_usecase.dart';

/// One social store for the whole app session — a plain (non-autoDispose)
/// provider, same reasoning as `competitionRepositoryProvider`.
final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return InMemorySocialRepository();
});

/// Reuses the same local identity progression/competition already
/// resolve, so friend requests, friendships, and the activity feed all
/// key off the same user across every feature.
final currentSocialUserIdProvider = Provider<String>((ref) {
  return ref.watch(currentProgressionUserIdProvider);
});

final socialMockScenarioProvider = Provider<SocialMockScenario>((ref) {
  return SocialMockScenario.normal;
});

/// Same seam as `competitionClockProvider` — tests override this instead
/// of depending on real wall-clock time.
final socialClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final sendFriendRequestUseCaseProvider = Provider((ref) {
  return SendFriendRequestUseCase(ref.watch(socialRepositoryProvider));
});

final acceptFriendRequestUseCaseProvider = Provider((ref) {
  return AcceptFriendRequestUseCase(ref.watch(socialRepositoryProvider));
});

final rejectFriendRequestUseCaseProvider = Provider((ref) {
  return RejectFriendRequestUseCase(ref.watch(socialRepositoryProvider));
});

final removeFriendUseCaseProvider = Provider((ref) {
  return RemoveFriendUseCase(ref.watch(socialRepositoryProvider));
});

final getFriendsUseCaseProvider = Provider((ref) {
  return GetFriendsUseCase(ref.watch(socialRepositoryProvider));
});

final getPendingRequestsUseCaseProvider = Provider((ref) {
  return GetPendingRequestsUseCase(ref.watch(socialRepositoryProvider));
});

final getActivityFeedUseCaseProvider = Provider((ref) {
  return GetActivityFeedUseCase(ref.watch(socialRepositoryProvider));
});

final setProfileVisibilityUseCaseProvider = Provider((ref) {
  return SetProfileVisibilityUseCase(ref.watch(socialRepositoryProvider));
});

final getPublicProfileUseCaseProvider = Provider((ref) {
  return GetPublicProfileUseCase(
    ref.watch(socialRepositoryProvider),
    ref.watch(progressionRepositoryProvider),
    ref.watch(competitionRepositoryProvider),
  );
});

/// One profile lookup per (viewer, target) pair — `autoDispose` since a
/// profile view is a transient screen, not session-lived state like
/// `socialControllerProvider`.
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfileResult, String>((ref, targetUserId) {
      final viewerId = ref.watch(currentSocialUserIdProvider);
      final displayName =
          ref.watch(authStateNotifierProvider).session?.user.displayName ??
          'You';
      final useCase = ref.watch(getPublicProfileUseCaseProvider);
      return useCase(
        viewerId: viewerId,
        targetUserId: targetUserId,
        targetDisplayName: displayName,
      );
    });
