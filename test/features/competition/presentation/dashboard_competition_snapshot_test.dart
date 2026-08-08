import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/competition/presentation/providers/competition_providers.dart';
import 'package:forge/features/competition/presentation/widgets/dashboard_competition_snapshot.dart';

import '../../../support/fake_auth_overrides.dart';

/// Covers spec section 35's Dashboard-integration acceptance points beyond
/// what the Dashboard golden tests already lock in visually: no overflow at
/// either reference width, correct accessible semantics, and that
/// provisional values stay explicitly labeled.
void main() {
  final fixedNow = DateTime.utc(2026, 8, 10, 9);

  Widget wrap({required double width}) {
    return ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        competitionClockProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: const DashboardCompetitionSnapshot(),
          ),
        ),
      ),
    );
  }

  testWidgets('renders without overflow at the mobile reference width', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(width: 412));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at the wide/tablet reference width', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(width: 1024));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes one accessible semantics label naming league, rank, '
      'zone, and that the score is a preview', (tester) async {
    await tester.pumpWidget(wrap(width: 412));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(
      find.byType(DashboardCompetitionSnapshot),
    );
    expect(semantics.label, contains('League'));
    expect(semantics.label, contains('rank'));
    expect(semantics.label, contains('preview only'));
  });

  testWidgets('the weekly score is always labeled as a preview, never as a '
      'confirmed value', (tester) async {
    await tester.pumpWidget(wrap(width: 412));
    await tester.pumpAndSettle();

    expect(find.textContaining('(preview)'), findsOneWidget);
    expect(find.textContaining('confirmed'), findsNothing);
  });

  testWidgets('never renders recovery-mode or other sensitive status', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(width: 412));
    await tester.pumpAndSettle();

    expect(find.textContaining('recovery'), findsNothing);
    expect(find.textContaining('Recovery'), findsNothing);
  });
}
