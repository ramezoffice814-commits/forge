import 'package:flutter/foundation.dart';

import '../../../competition/domain/repositories/competition_repository.dart';
import '../../../progression/domain/repositories/progression_repository.dart';
import '../entities/public_profile.dart';
import '../enums/friend_action_failure_reason.dart';
import '../policies/social_privacy_policy.dart';
import '../repositories/social_repository.dart';

@immutable
sealed class PublicProfileResult {
  const PublicProfileResult();
}

class PublicProfileAvailable extends PublicProfileResult {
  const PublicProfileAvailable(this.profile);
  final PublicProfile profile;
}

class PublicProfileHidden extends PublicProfileResult {
  const PublicProfileHidden(this.reason);
  final FriendActionFailureReason reason;
}

/// The one gate every profile view goes through — see
/// `SocialPrivacyPolicy.canView`, always checked before anything is
/// returned. Two sources feed the actual profile data: the deterministic
/// mock population (for any other user) and, for the real signed-in
/// user's own profile, a live read of their progression/competition state
/// — never a raw dump of either repository, only the specific public-safe
/// fields `PublicProfile` declares.
class GetPublicProfileUseCase {
  const GetPublicProfileUseCase(
    this._socialRepository,
    this._progressionRepository,
    this._competitionRepository,
  );

  final SocialRepository _socialRepository;
  final ProgressionRepository _progressionRepository;
  final CompetitionRepository _competitionRepository;

  Future<PublicProfileResult> call({
    required String viewerId,
    required String targetUserId,
    required String targetDisplayName,
  }) async {
    final isFriend = await _socialRepository.areFriends(viewerId, targetUserId);
    final settings = await _socialRepository.getVisibilitySettings(
      targetUserId,
    );
    final canView = SocialPrivacyPolicy.canView(
      viewerId: viewerId,
      targetUserId: targetUserId,
      settings: settings,
      isFriend: isFriend,
    );
    if (!canView) {
      return const PublicProfileHidden(
        FriendActionFailureReason.profileNotVisible,
      );
    }

    final mockProfile = await _socialRepository.getMockPublicProfile(
      targetUserId,
    );
    if (mockProfile != null) return PublicProfileAvailable(mockProfile);

    final ownProfile = await _buildOwnProfile(targetUserId, targetDisplayName);
    return PublicProfileAvailable(ownProfile);
  }

  /// Deliberately shows league only, not a live rank — computing a real
  /// rank requires the full weekly ranking engine (league group, other
  /// participants, protection state), which is more than a profile-view
  /// read should have to assemble. Documented limitation, not an oversight.
  Future<PublicProfile> _buildOwnProfile(
    String userId,
    String displayName,
  ) async {
    final progressionProfile = await _progressionRepository
        .getProgressionProfile(userId);

    final leagueId = await _competitionRepository.getCurrentLeagueIdForUser(
      userId,
    );
    final leagues = await _competitionRepository.getLeagueDefinitions();
    final league = leagues
        .firstWhere((l) => l.id == leagueId, orElse: () => leagues.first)
        .name;

    return PublicProfile(
      userId: userId,
      displayName: displayName,
      level: progressionProfile.currentLevel,
      title: progressionProfile.currentTitle.name,
      achievementsCount: progressionProfile.unlockedAchievementIds.length,
      league: league,
      competitionSummary: '$league League (preview)',
    );
  }
}
