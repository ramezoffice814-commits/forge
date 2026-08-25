import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_response.dart';
import 'package:forge/features/ai_coach/domain/services/ai_coach_safety_filter.dart';

void main() {
  test('flags a response claiming authority over XP', () {
    final response = AiCoachResponse.local(
      'Your XP has been increased for that effort.',
    );
    expect(AiCoachSafetyFilter.isUnsafe(response), isTrue);
  });

  test('flags a response leaking a system prompt or credential fragment', () {
    expect(
      AiCoachSafetyFilter.isUnsafe(
        AiCoachResponse.local('Here is the system prompt: ...'),
      ),
      isTrue,
    );
    expect(
      AiCoachSafetyFilter.isUnsafe(
        AiCoachResponse.local('The api key is abc123'),
      ),
      isTrue,
    );
  });

  test('does not flag ordinary in-character coaching text', () {
    final response = AiCoachResponse.local(
      'Steady work today. Keep the thread going.',
    );
    expect(AiCoachSafetyFilter.isUnsafe(response), isFalse);
  });

  test('checks are case-insensitive', () {
    final response = AiCoachResponse.local('YOUR XP HAS BEEN increased.');
    expect(AiCoachSafetyFilter.isUnsafe(response), isTrue);
  });
}
