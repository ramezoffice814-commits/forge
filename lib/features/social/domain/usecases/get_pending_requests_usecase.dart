import 'package:flutter/foundation.dart';

import '../entities/friend_request.dart';
import '../entities/public_profile.dart';
import '../repositories/social_repository.dart';

@immutable
class PendingFriendRequestView {
  const PendingFriendRequestView({
    required this.request,
    required this.senderProfile,
  });

  final FriendRequest request;
  final PublicProfile senderProfile;
}

/// Incoming (not outgoing) pending requests, each paired with the
/// sender's public profile so the UI never has to make a second lookup.
class GetPendingRequestsUseCase {
  const GetPendingRequestsUseCase(this._repository);

  final SocialRepository _repository;

  Future<List<PendingFriendRequestView>> call(String userId) async {
    final requests = await _repository.incomingRequestsFor(userId);
    final views = <PendingFriendRequestView>[];
    for (final request in requests) {
      final profile = await _repository.getMockPublicProfile(request.senderId);
      if (profile != null) {
        views.add(
          PendingFriendRequestView(request: request, senderProfile: profile),
        );
      }
    }
    return views;
  }
}
