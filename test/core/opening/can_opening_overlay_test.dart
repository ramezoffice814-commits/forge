import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/opening/can_ignition_painter.dart';
import 'package:forge/core/opening/can_opening_overlay.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/onboarding/presentation/onboarding_status.dart';
import 'package:forge/features/onboarding/presentation/onboarding_status_notifier.dart';

/// [CanOpeningOverlay] is presentation-only — it never touches routing or
/// auth state (see the widget's own doc comment) — so "correct
/// destination after animation"/"authenticated destination"/
/// "unauthenticated destination"/"no duplicate navigation" for the *real*
/// app are already covered by the existing full-`ForgeApp` integration
/// suite (`auth_onboarding_flow_test.dart`, `dashboard_navigation_test.dart`,
/// etc.) — all of which continue to pass unmodified with this overlay
/// wired in, since every one of them settles via `pumpAndSettle()`, which
/// fast-forwards through the overlay's controller/timer chain exactly as
/// it would any other animation. This file tests the overlay's own
/// contract in isolation instead: sequence selection, timing, dismissal,
/// reduced motion, and the safety-cap fallback.
class _IncompleteOnboardingNotifier extends OnboardingStatusNotifier {
  @override
  OnboardingStatus build() => const OnboardingStatusLoaded(false);
}

class _CompletedOnboardingNotifier extends OnboardingStatusNotifier {
  @override
  OnboardingStatus build() => const OnboardingStatusLoaded(true);
}

/// Never resolves — simulates a stuck/failed onboarding-status read, to
/// prove the overlay's safety cap still dismisses it rather than blocking
/// the app forever.
class _StuckOnboardingNotifier extends OnboardingStatusNotifier {
  @override
  OnboardingStatus build() => const OnboardingStatusLoading();
}

/// Pumps in small repeated steps rather than one large jump — safer for
/// asserting on animation/timer state than a single big `pump(duration)`,
/// which only guarantees the *final* frame reflects everything that fired
/// during the jump, not that every intermediate `setState` had a chance
/// to independently settle.
Future<void> _pumpBy(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  var remaining = total;
  while (remaining > Duration.zero) {
    final thisStep = remaining < step ? remaining : step;
    await tester.pump(thisStep);
    remaining -= thisStep;
  }
}

Widget _wrap({
  required OnboardingStatusNotifier Function() notifier,
  bool reducedMotion = false,
}) {
  return ProviderScope(
    overrides: [onboardingStatusProvider.overrideWith(notifier)],
    child: MaterialApp(
      theme: ForgeTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: CanOpeningOverlay(
        child: const Scaffold(body: Center(child: Text('destination-content'))),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders CAN semantics immediately and hides the destination content '
    'behind it (first/full sequence, opening route renders)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(notifier: _IncompleteOnboardingNotifier.new),
      );
      // Let the post-frame callback that starts the controller run.
      await tester.pump();
      await tester.pump();

      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('CAN'), findsOneWidget);
      handle.dispose();

      // Destination content exists in the tree (the router already
      // resolved it) but is excluded from the accessibility tree and
      // visually covered — not yet what the user should be interacting
      // with.
      expect(find.text('destination-content'), findsOneWidget);
    },
  );

  testWidgets('first/full sequence: still showing well before 2.5s, dismissed '
      'shortly after', (tester) async {
    await tester.pumpWidget(_wrap(notifier: _IncompleteOnboardingNotifier.new));
    await tester.pump();
    await tester.pump();

    await _pumpBy(tester, const Duration(milliseconds: 2000));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('CAN'), findsOneWidget);
    handle.dispose();

    // Full duration (2500ms) + fade-out (320ms) + a margin.
    await _pumpBy(tester, const Duration(milliseconds: 900));
    final handle2 = tester.ensureSemantics();
    expect(find.bySemanticsLabel('CAN'), findsNothing);
    handle2.dispose();
  });

  testWidgets('returning fast path: a completed-onboarding user dismisses well '
      'before the full-sequence duration would have elapsed', (tester) async {
    await tester.pumpWidget(_wrap(notifier: _CompletedOnboardingNotifier.new));
    await tester.pump();
    await tester.pump();

    // Comfortably past the fast path's own ~1.1s + fade, comfortably
    // before the full sequence's ~2.5s would even be halfway dismissing.
    await _pumpBy(tester, const Duration(milliseconds: 1600));

    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('CAN'), findsNothing);
    handle.dispose();
    expect(find.text('destination-content'), findsOneWidget);
  });

  testWidgets('reduced motion: dismisses very quickly and never uses the '
      'ignition/orbit/arrow painter', (tester) async {
    await tester.pumpWidget(
      _wrap(notifier: _IncompleteOnboardingNotifier.new, reducedMotion: true),
    );
    await tester.pump();
    await tester.pump();

    // While showing, the ignition/orbit/arrow painter should never be
    // used — reduced motion is a plain wordmark fade only (spec: no
    // spinning/scaling/sweeping-arrow/repeated-pulse). Checked by
    // painter type specifically, not by CustomPaint's mere presence —
    // Flutter's own Material/text rendering can use CustomPaint for
    // unrelated reasons (e.g. selection handles), so asserting its
    // total absence would be a fragile, unrelated-to-intent check.
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CanIgnitionPainter,
      ),
      findsNothing,
    );

    // Reduced-motion target is ~0.4-0.8s total (600ms controller here)
    // plus the shared 320ms fade-out — comfortably past both:
    await _pumpBy(tester, const Duration(milliseconds: 1100));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('CAN'), findsNothing);
    handle.dispose();
  });

  testWidgets(
    'settles exactly once: no duplicate destination content, and once '
    'removed it stays removed on further pumps (no replay)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(notifier: _CompletedOnboardingNotifier.new),
      );
      await tester.pumpAndSettle();

      expect(find.text('destination-content'), findsOneWidget);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('CAN'), findsNothing);
      handle.dispose();

      // Further pumps (simulating time passing with the same State,
      // matching a background/foreground resume that doesn't recreate
      // the widget) must not bring the overlay back.
      await _pumpBy(tester, const Duration(seconds: 2));
      expect(find.text('destination-content'), findsOneWidget);
      final handle2 = tester.ensureSemantics();
      expect(find.bySemanticsLabel('CAN'), findsNothing);
      handle2.dispose();
    },
  );

  testWidgets(
    'safety cap: if onboarding status never resolves, the overlay still '
    'dismisses itself rather than blocking the app forever',
    (tester) async {
      await tester.pumpWidget(_wrap(notifier: _StuckOnboardingNotifier.new));
      await tester.pump();
      await tester.pump();

      // Still showing well before the 4s safety cap.
      await _pumpBy(tester, const Duration(seconds: 2));
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('CAN'), findsOneWidget);
      handle.dispose();

      // Past the 4s cap plus fade-out.
      await _pumpBy(tester, const Duration(milliseconds: 2500));
      final handle2 = tester.ensureSemantics();
      expect(find.bySemanticsLabel('CAN'), findsNothing);
      handle2.dispose();
      expect(find.text('destination-content'), findsOneWidget);
    },
  );
}
