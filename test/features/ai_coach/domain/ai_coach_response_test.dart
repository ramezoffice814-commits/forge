import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_response.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_coach_suggested_action.dart';

void main() {
  test('tryParse accepts a well-formed response', () {
    final response = AiCoachResponse.tryParse({
      'message': 'Steady work today.',
      'reasoningSummary': 'Consistent effort this week.',
      'suggestedActions': ['openProgress', 'explainMission'],
    });

    expect(response, isNotNull);
    expect(response!.message, 'Steady work today.');
    expect(response.reasoningSummary, 'Consistent effort this week.');
    expect(response.suggestedActions, [
      AiCoachSuggestedAction.openProgress,
      AiCoachSuggestedAction.explainMission,
    ]);
  });

  test('tryParse returns null for a missing message', () {
    expect(AiCoachResponse.tryParse({'reasoningSummary': 'x'}), isNull);
  });

  test('tryParse returns null for a non-string message', () {
    expect(AiCoachResponse.tryParse({'message': 42}), isNull);
  });

  test('tryParse returns null for an empty message', () {
    expect(AiCoachResponse.tryParse({'message': ''}), isNull);
  });

  test('tryParse returns null for a message over the length cap', () {
    expect(AiCoachResponse.tryParse({'message': 'a' * 2001}), isNull);
  });

  test('tryParse accepts a message exactly at the length cap', () {
    expect(AiCoachResponse.tryParse({'message': 'a' * 2000}), isNotNull);
  });

  test('tryParse silently drops unparseable suggested actions', () {
    final response = AiCoachResponse.tryParse({
      'message': 'ok',
      'suggestedActions': ['grantXp', 'deleteAccount', 'openProgress'],
    });
    expect(response!.suggestedActions, [AiCoachSuggestedAction.openProgress]);
  });

  test('tryParse ignores unknown JSON keys rather than failing', () {
    final response = AiCoachResponse.tryParse({
      'message': 'ok',
      'someFutureField': 'irrelevant',
    });
    expect(response, isNotNull);
  });

  test(
    'tryParse treats absent reasoningSummary/suggestedActions as empty/null',
    () {
      final response = AiCoachResponse.tryParse({'message': 'ok'});
      expect(response!.reasoningSummary, isNull);
      expect(response.suggestedActions, isEmpty);
    },
  );

  test(
    'local() never has a reasoningSummary, distinguishing it from a real parse',
    () {
      final response = AiCoachResponse.local('fallback text');
      expect(response.reasoningSummary, isNull);
    },
  );
}
