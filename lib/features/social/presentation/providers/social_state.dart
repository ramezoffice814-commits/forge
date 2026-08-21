import 'package:flutter/foundation.dart';

import '../../domain/entities/activity_event.dart';
import '../../domain/entities/profile_visibility_settings.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/usecases/get_pending_requests_usecase.dart';

@immutable
sealed class SocialState {
  const SocialState();
}

class SocialLoading extends SocialState {
  const SocialLoading();
}

class SocialError extends SocialState {
  const SocialError(this.message);

  final String message;
}

class SocialReady extends SocialState {
  const SocialReady({
    required this.friends,
    required this.pendingRequests,
    required this.activityFeed,
    required this.visibilitySettings,
    this.lastActionMessage,
  });

  final List<PublicProfile> friends;
  final List<PendingFriendRequestView> pendingRequests;
  final List<ActivityEvent> activityFeed;
  final ProfileVisibilitySettings visibilitySettings;

  /// A short, neutral, human-readable outcome of the most recent action
  /// (e.g. a blocked duplicate request) — cleared on the next successful
  /// refresh, same "don't vanish before it's seen" reasoning as
  /// `ProgressionReady.lastXpEvaluation`.
  final String? lastActionMessage;
}
