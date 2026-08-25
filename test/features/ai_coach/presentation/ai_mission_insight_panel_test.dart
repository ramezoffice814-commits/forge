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
import 'package:forge/features/missions/domain/entities/resolved_mission_instance.dart';
import 'package:forge/features/missions/domain/enums/mission_instance_authority.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';

import '../../../support/fake_secure_key_value_store.dart';
import '../../../support/mission_lifecycle_test_helpers.dart';

class _StubClient implements AiCoachClient {
  _StubClient(this._response);
  final AiCoachResponse _response;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async => _response;
}

void main() {
  final resolved = ResolvedMissionInstance(
    instance: testMissionInstance(),
    authority: MissionInstanceAuthority.localOnly,
  );

  Widget wrap({
    required AiPrivacyLevel privacyLevel,
    required AiCoachClient client,
    required ResolvedMissionInstance? resolvedMission,
  }) {
    return ProviderScope(
      overrides: [
        aiPrivacyLevelProvider.overrideWith((ref) => privacyLevel),
        aiCoachClientProvider.overrideWithValue(client),
        aiCoachCacheStoreProvider.overrideWithValue(
          AiCoachCacheStore(FakeSecureKeyValueStore()),
        ),
        resolvedMissionInstanceProvider.overrideWithValue(resolvedMission),
      ],
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: const Scaffold(body: AiMissionInsightPanel(displayName: 'Alex')),
      ),
    );
  }

  testWidgets('renders nothing when AI coaching is disabled', (tester) async {
    await tester.pumpWidget(
      wrap(
        privacyLevel: AiPrivacyLevel.disabled,
        client: _StubClient(AiCoachResponse.local('should never show')),
        resolvedMission: resolved,
      ),
    );
    await tester.pump();

    expect(find.text('should never show'), findsNothing);
    expect(find.byType(AiMissionInsightPanel), findsOneWidget);
  });

  testWidgets('renders nothing when there is no authoritative mission yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        privacyLevel: AiPrivacyLevel.fullContext,
        client: _StubClient(AiCoachResponse.local('should never show')),
        resolvedMission: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('should never show'), findsNothing);
  });

  testWidgets('shows the AI message once resolved', (tester) async {
    await tester.pumpWidget(
      wrap(
        privacyLevel: AiPrivacyLevel.fullContext,
        client: _StubClient(AiCoachResponse.local('this fits your pace today')),
        resolvedMission: resolved,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('this fits your pace today'), findsOneWidget);
  });

  testWidgets('renders nothing while the response is still resolving', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        privacyLevel: AiPrivacyLevel.fullContext,
        client: _StubClient(AiCoachResponse.local('done')),
        resolvedMission: resolved,
      ),
    );
    // No pumpAndSettle here — the fallback repository call hasn't
    // resolved yet, and this widget must never show a loading state
    // that could hold up the rest of the card around it.
    expect(find.text('done'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });
}
