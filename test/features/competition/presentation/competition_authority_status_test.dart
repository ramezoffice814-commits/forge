import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/services/cached_leaderboard_fetch.dart';
import 'package:forge/features/competition/presentation/providers/competition_state.dart';

void main() {
  test(
    'no confirmed standing yet is provisionalOnly, regardless of freshness',
    () {
      expect(
        resolveCompetitionAuthorityStatus(
          hasConfirmedStanding: false,
          freshness: LeaderboardFreshness.fresh,
        ),
        CompetitionAuthorityStatus.provisionalOnly,
      );
    },
  );

  test(
    'a fresh confirmed standing overrides provisional — reported confirmed',
    () {
      expect(
        resolveCompetitionAuthorityStatus(
          hasConfirmedStanding: true,
          freshness: LeaderboardFreshness.fresh,
        ),
        CompetitionAuthorityStatus.confirmed,
      );
    },
  );

  test(
    'a confirmed standing from a stale cache is reported confirmedStale, never plain confirmed',
    () {
      expect(
        resolveCompetitionAuthorityStatus(
          hasConfirmedStanding: true,
          freshness: LeaderboardFreshness.cachedStale,
        ),
        CompetitionAuthorityStatus.confirmedStale,
      );
    },
  );

  test(
    'a confirmed standing is never demoted back to provisionalOnly just because a later fetch failed unavailable',
    () {
      // "unavailable" only happens when there is no cache at all — if a
      // standing already exists, the caller keeps the previous one (see
      // CompetitionController.refreshConfirmedWeeklyStanding), so this
      // combination documents that hasConfirmedStanding staying true is
      // the caller's responsibility, not this function's.
      expect(
        resolveCompetitionAuthorityStatus(
          hasConfirmedStanding: true,
          freshness: LeaderboardFreshness.unavailable,
        ),
        isNot(CompetitionAuthorityStatus.provisionalOnly),
      );
    },
  );
}
