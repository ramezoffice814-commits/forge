import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_coach_suggested_action.dart';

void main() {
  test('tryParse resolves every known action name', () {
    for (final action in AiCoachSuggestedAction.values) {
      expect(AiCoachSuggestedAction.tryParse(action.name), action);
    }
  });

  test('tryParse returns null for an unknown string, never throws', () {
    expect(AiCoachSuggestedAction.tryParse('grantXp'), isNull);
    expect(AiCoachSuggestedAction.tryParse('deleteAccount'), isNull);
    expect(AiCoachSuggestedAction.tryParse(''), isNull);
    expect(AiCoachSuggestedAction.tryParse('startmission'), isNull);
  });
}
