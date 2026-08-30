import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/progression/presentation/pages/progression_page.dart';
import 'package:forge/shared/widgets/forge_progress_ring.dart';
import 'package:go_router/go_router.dart';

import '../../../../support/fake_auth_overrides.dart';

void main() {
  Future<void> pumpAtWidth(
    WidgetTester tester,
    double width,
    Widget child,
  ) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  double ringSize(WidgetTester tester) =>
      tester.widget<ForgeProgressRing>(find.byType(ForgeProgressRing)).size;

  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/progress',
      routes: [
        GoRoute(
          path: '/progress',
          name: 'progress',
          builder: (context, state) => const ProgressionPage(),
        ),
        GoRoute(
          path: '/awards',
          name: 'awards',
          builder: (context, state) =>
              const Scaffold(body: Text('awards-page-marker')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
      ],
      child: MaterialApp.router(theme: ForgeTheme.dark(), routerConfig: router),
    );
  }

  testWidgets('shows level, title, and category growth once loaded', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('XP (preview'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Category growth'), findsOneWidget);
  });

  testWidgets('shows a recent-achievements preview with a working "View '
      'all" link to Awards', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('Recent achievements'), findsOneWidget);

    final viewAll = find.text('View all');
    await tester.ensureVisible(viewAll);
    await tester.pumpAndSettle();
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    expect(find.text('awards-page-marker'), findsOneWidget);
  });

  testWidgets('the XP preview is explicitly labeled non-authoritative', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('not yet confirmed'), findsOneWidget);
  });

  testWidgets('the level ring announces level and percent-to-next-level for a '
      'screen reader, not just the bare level number visually shown '
      'inside it (Roadmap Item 19 accessibility pass)', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(RegExp(r'Level \d+, \d+ percent to next level')),
      findsOneWidget,
    );
    semanticsHandle.dispose();
  });

  testWidgets('Title and Category growth are exposed as semantic headers for '
      'screen-reader section navigation', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final titleNode = tester.getSemantics(find.text('Title'));
    expect(titleNode.flagsCollection.isHeader, isTrue);
    final categoryNode = tester.getSemantics(find.text('Category growth'));
    expect(categoryNode.flagsCollection.isHeader, isTrue);

    semanticsHandle.dispose();
  });

  group('responsive level ring (Mobile Polish Pass 1)', () {
    testWidgets(
      'renders at the original 180px on a normal phone width, unchanged',
      (tester) async {
        await pumpAtWidth(tester, 412, wrap());
        expect(tester.takeException(), isNull);
        expect(ringSize(tester), 180);
      },
    );

    testWidgets(
      'stays capped at 180px on a wide/tablet width, not growing oversized',
      (tester) async {
        await pumpAtWidth(tester, 1024, wrap());
        expect(tester.takeException(), isNull);
        expect(ringSize(tester), 180);
      },
    );

    testWidgets(
      'shrinks below 180px on a narrower-than-preferred width, with no '
      'overflow',
      (tester) async {
        await pumpAtWidth(tester, 200, wrap());
        expect(tester.takeException(), isNull);
        expect(ringSize(tester), lessThan(180));
        expect(ringSize(tester), greaterThanOrEqualTo(140));
      },
    );

    testWidgets('maintains circular geometry (rendered width == height) at '
        'every size tested above', (tester) async {
      for (final width in [200.0, 412.0, 1024.0]) {
        await pumpAtWidth(tester, width, wrap());
        expect(tester.takeException(), isNull);
        final renderedSize = tester.getSize(find.byType(ForgeProgressRing));
        expect(renderedSize.width, renderedSize.height);
      }
    });
  });

  group('responsiveLevelRingSize (pure function)', () {
    // Direct unit coverage of the clamp formula itself, independent of the
    // full page's own layout — a pathologically narrow container (e.g.
    // 100px) triggers unrelated pre-existing overflow elsewhere on this
    // page that has nothing to do with the ring, so the "falls back to
    // raw availableWidth below the preferred floor" branch is proven here
    // instead of through a full widget pump.
    test('caps at 180 once available width reaches or exceeds it', () {
      expect(responsiveLevelRingSize(180), 180);
      expect(responsiveLevelRingSize(500), 180);
      expect(responsiveLevelRingSize(1024), 180);
    });

    test('scales down continuously between the 140-180 range', () {
      expect(responsiveLevelRingSize(160), 160);
      expect(responsiveLevelRingSize(140), 140);
    });

    test('falls back to the raw available width below the preferred floor, '
        'never exceeding it — guarantees no overflow', () {
      expect(responsiveLevelRingSize(100), 100);
      expect(responsiveLevelRingSize(0), 0);
    });
  });
}
