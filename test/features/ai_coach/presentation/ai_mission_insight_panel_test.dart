import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/ai_coach/data/ai_coach_cache_store.dart';
import 'package:forge/features/ai_coach/data/ai_coach_client.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_request.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_response.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:forge/features/ai_coach/presentation/widgets/ai_mission_insight_panel.dart';

import '../../../support/fake_secure_key_value_store.dart';

class _StubClient implements AiCoachClient {
  _StubClient(this._response);
  final AiCoachResponse _response;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async => _response;
}

void main() {
  Widget wrap({
    required AiPrivacyLevel privacyLevel,
    required AiCoachClient client,
  }) {
    return ProviderScope(
      overrides: [
        aiPrivacyLevelProvider.overrideWith((ref) => privacyLevel),
        aiCoachClientProvider.overrideWithValue(client),
        aiCoachCacheStoreProvider.overrideWithValue(
          AiCoachCacheStore(FakeSecureKeyValueStore()),
        ),
      ],
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: const AiMissionInsightPanel(
            displayName: 'Alex',
            missionTitle: 'Morning run',
            missionCategory: 'fitness',
            missionDifficulty: 'medium',
          ),
        ),
      ),
    );
  }

  testWidgets('renders nothing when AI coaching is disabled', (tester) async {
    await tester.pumpWidget(
      wrap(
        privacyLevel: AiPrivacyLevel.disabled,
        client: _StubClient(AiCoachResponse.local('should never show')),
      ),
    );
    await tester.pump();

    expect(find.text('should never show'), findsNothing);
    expect(find.byType(AiMissionInsightPanel), findsOneWidget);
  });

  testWidgets('shows the AI message once resolved', (tester) async {
    await tester.pumpWidget(
      wrap(
        privacyLevel: AiPrivacyLevel.fullContext,
        client: _StubClient(AiCoachResponse.local('this fits your pace today')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('this fits your pace today'), findsOneWidget);
  });

  testWidgets('shows a loading indicator before the response resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        privacyLevel: AiPrivacyLevel.fullContext,
        client: _StubClient(AiCoachResponse.local('done')),
      ),
    );
    expect(find.text('Thinking…'), findsOneWidget);
  });
}
