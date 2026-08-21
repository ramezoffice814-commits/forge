import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/services/offline_mission_fallback.dart';

void main() {
  group('OfflineMissionAssignmentResolver.resolve', () {
    test('a cached confirmed assignment always wins first', () {
      final result = OfflineMissionAssignmentResolver.resolve(
        cachedConfirmedMissionInstanceId: 'confirmed-1',
        existingValidProvisionalMissionInstanceId: 'provisional-1',
        buildOfflineFallbackMissionInstanceId: () => 'fallback-1',
      );
      expect(result.source, MissionAssignmentSource.cachedConfirmed);
      expect(result.missionInstanceId, 'confirmed-1');
      expect(result.isProvisional, isFalse);
    });

    test(
      'falls back to an existing valid provisional assignment when no confirmed one exists',
      () {
        final result = OfflineMissionAssignmentResolver.resolve(
          cachedConfirmedMissionInstanceId: null,
          existingValidProvisionalMissionInstanceId: 'provisional-1',
          buildOfflineFallbackMissionInstanceId: () => 'fallback-1',
        );
        expect(result.source, MissionAssignmentSource.existingProvisional);
        expect(result.missionInstanceId, 'provisional-1');
        expect(result.isProvisional, isTrue);
      },
    );

    test(
      'falls back to a freshly-built offline mission only when nothing else is available',
      () {
        var buildCalled = false;
        final result = OfflineMissionAssignmentResolver.resolve(
          cachedConfirmedMissionInstanceId: null,
          existingValidProvisionalMissionInstanceId: null,
          buildOfflineFallbackMissionInstanceId: () {
            buildCalled = true;
            return 'fallback-1';
          },
        );
        expect(buildCalled, isTrue);
        expect(result.source, MissionAssignmentSource.offlineFallback);
        expect(result.missionInstanceId, 'fallback-1');
        expect(result.isProvisional, isTrue);
      },
    );

    test(
      'the fallback builder is never invoked when a confirmed or provisional assignment already exists',
      () {
        var buildCalled = false;
        OfflineMissionAssignmentResolver.resolve(
          cachedConfirmedMissionInstanceId: 'confirmed-1',
          existingValidProvisionalMissionInstanceId: null,
          buildOfflineFallbackMissionInstanceId: () {
            buildCalled = true;
            return 'fallback-1';
          },
        );
        expect(buildCalled, isFalse);
      },
    );

    test('only cachedConfirmed is ever non-provisional', () {
      for (final source in MissionAssignmentSource.values) {
        final result = ResolvedMissionAssignment(
          source: source,
          missionInstanceId: 'x',
        );
        expect(
          result.isProvisional,
          source != MissionAssignmentSource.cachedConfirmed,
        );
      }
    });
  });
}
