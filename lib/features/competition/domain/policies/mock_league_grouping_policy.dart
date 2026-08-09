import '../entities/league_definition.dart';
import '../entities/league_group.dart';

/// One participant's grouping-relevant context — deliberately narrow.
/// [recentScoreBand] is a coarse bucket (not an exact score) and
/// [timezoneBucket] is a coarse region tag, matching the module rule
/// against grouping by exact personal behavior or sensitive attributes.
class CompetitionGroupingContext {
  const CompetitionGroupingContext({
    required this.userId,
    required this.isRookie,
    required this.recentScoreBand,
    required this.timezoneBucket,
  });

  final String userId;
  final bool isRookie;
  final int recentScoreBand;
  final String timezoneBucket;
}

/// Deterministic weekly group assignment — no `Random()`, ever. Same input
/// always produces the same groups, sorted only by already-coarse,
/// non-sensitive fields plus a stable `userId` tiebreak (spec section 17).
abstract final class MockLeagueGroupingPolicy {
  static List<LeagueGroup> buildGroups({
    required String seasonId,
    required int weekNumber,
    required LeagueDefinition league,
    required List<CompetitionGroupingContext> participants,
    required DateTime createdAt,
  }) {
    if (participants.isEmpty) return const [];

    final buckets = <String, List<CompetitionGroupingContext>>{};
    for (final participant in participants) {
      final key = '${participant.isRookie}-${participant.recentScoreBand}';
      buckets.putIfAbsent(key, () => []).add(participant);
    }

    final groups = <LeagueGroup>[];
    final sortedKeys = buckets.keys.toList()..sort();

    for (final key in sortedKeys) {
      final bucketParticipants = buckets[key]!
        ..sort((a, b) {
          final byTimezone = a.timezoneBucket.compareTo(b.timezoneBucket);
          if (byTimezone != 0) return byTimezone;
          return a.userId.compareTo(b.userId);
        });

      for (
        var offset = 0;
        offset < bucketParticipants.length;
        offset += league.maxGroupSize
      ) {
        final chunk = bucketParticipants.skip(offset).take(league.maxGroupSize);
        final chunkIndex = offset ~/ league.maxGroupSize;
        groups.add(
          LeagueGroup(
            groupId: '$seasonId-w$weekNumber-${league.id}-$key-g$chunkIndex',
            seasonId: seasonId,
            weekNumber: weekNumber,
            leagueId: league.id,
            participantIds: chunk.map((p) => p.userId).toList(),
            maxSize: league.maxGroupSize,
            createdAt: createdAt,
          ),
        );
      }
    }

    return groups;
  }
}
