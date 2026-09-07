import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/config/ai_coach_mode.dart';

void main() {
  group('resolveAiCoachMode', () {
    test('live only when both the flag is set and Supabase is configured', () {
      expect(
        resolveAiCoachMode(aiCoachLiveFlag: true, isSupabaseConfigured: true),
        AiCoachMode.live,
      );
    });

    test('mock when the flag is set but Supabase is not configured', () {
      expect(
        resolveAiCoachMode(aiCoachLiveFlag: true, isSupabaseConfigured: false),
        AiCoachMode.mock,
      );
    });

    test('mock when Supabase is configured but the flag is off', () {
      expect(
        resolveAiCoachMode(aiCoachLiveFlag: false, isSupabaseConfigured: true),
        AiCoachMode.mock,
      );
    });

    test('mock when neither is set', () {
      expect(
        resolveAiCoachMode(aiCoachLiveFlag: false, isSupabaseConfigured: false),
        AiCoachMode.mock,
      );
    });

    test('never throws for any input combination', () {
      for (final flag in [true, false]) {
        for (final configured in [true, false]) {
          expect(
            () => resolveAiCoachMode(
              aiCoachLiveFlag: flag,
              isSupabaseConfigured: configured,
            ),
            returnsNormally,
          );
        }
      }
    });
  });
}
