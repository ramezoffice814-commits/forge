import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_state.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../data/mock/mock_social_seeder.dart';
import '../../domain/enums/friend_action_failure_reason.dart';
import '../../domain/enums/profile_visibility.dart';
import '../../domain/usecases/remove_friend_usecase.dart';
import '../../domain/usecases/respond_to_friend_request_result.dart';
import '../../domain/usecases/send_friend_request_usecase.dart';
import 'social_providers.dart';
import 'social_state.dart';

/// The single authoritative social session, mirroring
/// `CompetitionController`'s shape: a `ready` future callers await before
/// their first read, and every mutating action re-runs `_refresh` so the
/// three lists (friends/requests/activity) never drift out of sync with
/// the repository.
class SocialController extends Notifier<SocialState> {
  final Completer<void> _readyCompleter = Completer<void>();

  Future<void> get ready => _readyCompleter.future;

  @override
  SocialState build() {
    final authStatus = ref.watch(
      authStateNotifierProvider.select((s) => s.status),
    );
    if (authStatus == AuthStatus.unauthenticated) {
      ref.read(socialRepositoryProvider).clearForUser(_userId);
      return const SocialLoading();
    }

    Future.microtask(() async {
      await _loadOrSeed();
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    });
    return const SocialLoading();
  }

  String get _userId => ref.read(currentSocialUserIdProvider);

  Future<void> _loadOrSeed() async {
    final repository = ref.read(socialRepositoryProvider);
    final userId = _userId;
    final hasAnyState =
        (await repository.friendshipsFor(userId)).isNotEmpty ||
        (await repository.incomingRequestsFor(userId)).isNotEmpty;
    if (!hasAnyState) {
      await MockSocialSeeder.seed(
        repository,
        userId: userId,
        scenario: ref.read(socialMockScenarioProvider),
        now: ref.read(socialClockProvider)(),
      );
    }
    await _refresh();
  }

  Future<void> _refresh({String? lastActionMessage}) async {
    try {
      final userId = _userId;
      final friends = await ref.read(getFriendsUseCaseProvider)(userId);
      final pendingRequests = await ref.read(getPendingRequestsUseCaseProvider)(
        userId,
      );
      final activityFeed = await ref.read(getActivityFeedUseCaseProvider)(
        userId,
      );
      final visibilitySettings = await ref
          .read(socialRepositoryProvider)
          .getVisibilitySettings(userId);

      state = SocialReady(
        friends: friends,
        pendingRequests: pendingRequests,
        activityFeed: activityFeed,
        visibilitySettings: visibilitySettings,
        lastActionMessage: lastActionMessage,
      );
    } catch (_) {
      state = const SocialError("Couldn't load your friends right now.");
    }
  }

  Future<void> sendFriendRequest(String receiverId) async {
    final result = await ref.read(sendFriendRequestUseCaseProvider)(
      senderId: _userId,
      receiverId: receiverId,
      now: ref.read(socialClockProvider)(),
    );
    final message = switch (result) {
      SendFriendRequestSent() => 'Friend request sent.',
      SendFriendRequestBlocked(:final reason) => friendActionFailureMessage(
        reason,
      ),
    };
    await _refresh(lastActionMessage: message);
  }

  Future<void> acceptRequest(String requestId) async {
    final result = await ref.read(acceptFriendRequestUseCaseProvider)(
      requestId,
      now: ref.read(socialClockProvider)(),
    );
    final message = switch (result) {
      FriendRequestAccepted() => 'Friend request accepted.',
      RespondToFriendRequestFailed(:final reason) => friendActionFailureMessage(
        reason,
      ),
      FriendRequestRejected() => null,
    };
    await _refresh(lastActionMessage: message);
  }

  Future<void> rejectRequest(String requestId) async {
    final result = await ref.read(rejectFriendRequestUseCaseProvider)(
      requestId,
    );
    final message = switch (result) {
      FriendRequestRejected() => 'Friend request declined.',
      RespondToFriendRequestFailed(:final reason) => friendActionFailureMessage(
        reason,
      ),
      FriendRequestAccepted() => null,
    };
    await _refresh(lastActionMessage: message);
  }

  Future<void> removeFriend(String friendId) async {
    final result = await ref.read(removeFriendUseCaseProvider)(
      _userId,
      friendId,
    );
    final message = switch (result) {
      FriendRemoved() => 'Friend removed.',
      RemoveFriendFailed(:final reason) => friendActionFailureMessage(reason),
    };
    await _refresh(lastActionMessage: message);
  }

  Future<void> setVisibility(ProfileVisibility visibility) async {
    await ref.read(setProfileVisibilityUseCaseProvider)(
      _userId,
      visibility,
      now: ref.read(socialClockProvider)(),
    );
    await _refresh(lastActionMessage: 'Privacy setting updated.');
  }
}

final socialControllerProvider =
    NotifierProvider<SocialController, SocialState>(SocialController.new);
