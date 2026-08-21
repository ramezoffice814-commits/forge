import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/data/supabase/leaderboard_row_mapper.dart';
import 'package:forge/features/competition/domain/repositories/leaderboard_repository.dart';

void main() {
  group('parseWeeklyLeaderboardRow', () {
    Map<String, dynamic> validRow() => {
      'user_id': 'user-1',
      'season_id': 'season-1',
      'week_number': 3,
      'league_id': 'league-1',
      'league_name': 'Iron',
      'rank': 2,
      'confirmed_score': 41.5,
      'promotion_status': 'safeZone',
      'display_name': 'Ari',
      'avatar_path': null,
    };

    test('parses a well-formed row', () {
      final entry = parseWeeklyLeaderboardRow(validRow());
      expect(entry.userId, 'user-1');
      expect(entry.rank, 2);
      expect(entry.confirmedScore, 41.5);
      expect(entry.promotionStatus, 'safeZone');
    });

    test(
      'accepts a numeric score arriving as a string (Postgres numeric-over-PostgREST)',
      () {
        final row = validRow()..['confirmed_score'] = '41.5';
        expect(parseWeeklyLeaderboardRow(row).confirmedScore, 41.5);
      },
    );

    test('rejects a row missing a required field', () {
      final row = validRow()..remove('display_name');
      expect(
        () => parseWeeklyLeaderboardRow(row),
        throwsA(isA<MalformedLeaderboardRowException>()),
      );
    });

    test('rejects a row with the wrong type for a required field', () {
      final row = validRow()..['rank'] = 'first';
      expect(
        () => parseWeeklyLeaderboardRow(row),
        throwsA(isA<MalformedLeaderboardRowException>()),
      );
    });
  });

  group('parseSeasonLeaderboardRow', () {
    Map<String, dynamic> validRow() => {
      'user_id': 'user-1',
      'season_id': 'season-1',
      'final_league_id': 'league-1',
      'league_name': 'Iron',
      'rank_in_league': 5,
      'confirmed_score': 210.0,
      'promoted': true,
      'demoted': false,
      'display_name': 'Ari',
      'avatar_path': null,
    };

    test('parses a well-formed row', () {
      final entry = parseSeasonLeaderboardRow(validRow());
      expect(entry.promoted, isTrue);
      expect(entry.demoted, isFalse);
      expect(entry.confirmedScore, 210.0);
    });

    test('rejects a non-boolean promoted field', () {
      final row = validRow()..['promoted'] = 'yes';
      expect(
        () => parseSeasonLeaderboardRow(row),
        throwsA(isA<MalformedLeaderboardRowException>()),
      );
    });
  });
}
