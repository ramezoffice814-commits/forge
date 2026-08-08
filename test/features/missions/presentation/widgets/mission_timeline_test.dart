import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/missions/domain/events/mission_event.dart';
import 'package:forge/features/missions/domain/events/mission_event_source.dart';
import 'package:forge/features/missions/presentation/widgets/mission_timeline.dart';

void main() {
  const missionId = 'm1';
  const userId = 'u1';
  final at = DateTime.utc(2026, 8, 10, 9);

  testWidgets('renders nothing for an empty event list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: const Scaffold(body: MissionTimeline(events: [])),
      ),
    );
    expect(find.byType(MissionTimeline), findsOneWidget);
    expect(find.text('Mission assigned'), findsNothing);
  });

  testWidgets('shows the most recent event first, with friendly labels', (
    tester,
  ) async {
    final events = <MissionEvent>[
      MissionAssigned(
        eventId: 'e1',
        missionInstanceId: missionId,
        userId: userId,
        occurredAt: at,
        clientCreatedAt: at,
        sequenceNumber: 1,
        source: MissionEventSource.system,
        idempotencyKey: 'super-secret-idempotency-key-assigned',
      ),
      MissionAccepted(
        eventId: 'e2',
        missionInstanceId: missionId,
        userId: userId,
        occurredAt: at.add(const Duration(minutes: 1)),
        clientCreatedAt: at,
        sequenceNumber: 2,
        source: MissionEventSource.userAction,
        idempotencyKey: 'super-secret-idempotency-key-accepted',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(body: MissionTimeline(events: events)),
      ),
    );

    expect(find.text('Mission accepted'), findsOneWidget);
    expect(find.text('Mission assigned'), findsOneWidget);

    // Most-recent-first ordering: "accepted" (seq 2) renders above
    // "assigned" (seq 1).
    final acceptedY = tester.getTopLeft(find.text('Mission accepted')).dy;
    final assignedY = tester.getTopLeft(find.text('Mission assigned')).dy;
    expect(acceptedY, lessThan(assignedY));
  });

  testWidgets('never renders a raw idempotency key or event id', (
    tester,
  ) async {
    final events = <MissionEvent>[
      MissionAssigned(
        eventId: 'super-secret-event-id',
        missionInstanceId: missionId,
        userId: userId,
        occurredAt: at,
        clientCreatedAt: at,
        sequenceNumber: 1,
        source: MissionEventSource.system,
        idempotencyKey: 'super-secret-idempotency-key',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(body: MissionTimeline(events: events)),
      ),
    );

    expect(find.textContaining('super-secret'), findsNothing);
  });

  testWidgets('a validation failure shows its user-facing explanation', (
    tester,
  ) async {
    final events = <MissionEvent>[
      MissionValidationFailed(
        eventId: 'e1',
        missionInstanceId: missionId,
        userId: userId,
        occurredAt: at,
        clientCreatedAt: at,
        sequenceNumber: 1,
        source: MissionEventSource.localValidation,
        idempotencyKey: 'k1',
        reasonCodes: const ['binaryNotCompleted'],
        userFacingExplanation: 'Mark the mission as done to submit.',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(body: MissionTimeline(events: events)),
      ),
    );

    expect(find.text('Mark the mission as done to submit.'), findsOneWidget);
  });
}
