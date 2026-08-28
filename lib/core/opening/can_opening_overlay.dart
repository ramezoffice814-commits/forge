import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/presentation/onboarding_status.dart';
import '../../features/onboarding/presentation/onboarding_status_notifier.dart';
import '../theme/forge_tokens.dart';
import 'can_ignition_painter.dart';
import 'can_wordmark.dart';

enum _SequenceKind { full, fast, reduced }

/// Wraps the app's routed content with the CAN cinematic opening
/// (Roadmap Item 21) as a presentation-only overlay — it never reads or
/// influences routing/auth state directly. `AuthStateAwareRedirectPolicy`
/// still resolves the real destination on its own, immediately, exactly
/// as it did before this item; GoRouter's `refreshListenable` fires the
/// instant auth/onboarding actually resolve, often well inside a second
/// in mock mode. Coupling the redirect itself to a ~2.5s animation would
/// have meant either delaying real navigation (a router behavior change,
/// explicitly out of scope and risky) or racing it. Instead, this overlay
/// simply covers the screen for a short, fixed sequence and dissolves to
/// reveal whatever the router has already silently navigated to
/// underneath — "animation is presentation only," per this item's own
/// router-safety instruction.
///
/// Shown at most once per app process lifetime: this widget's [State] is
/// created once when [MaterialApp.router]'s `builder` mounts it, and
/// Flutter does not recreate that State on a background/foreground
/// lifecycle resume — only on a genuine cold process start, which is
/// exactly when it should replay.
class CanOpeningOverlay extends ConsumerStatefulWidget {
  const CanOpeningOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CanOpeningOverlay> createState() => _CanOpeningOverlayState();
}

class _CanOpeningOverlayState extends ConsumerState<CanOpeningOverlay>
    with SingleTickerProviderStateMixin {
  static const _fullDuration = Duration(milliseconds: 2500);
  static const _fastDuration = Duration(milliseconds: 1100);
  static const _reducedDuration = Duration(milliseconds: 600);
  static const _fadeOutDuration = Duration(milliseconds: 320);

  // Hard safety cap: forces dismissal even if the sequence decision or
  // controller somehow never resolves/completes, so the app can never
  // get stuck behind this overlay — the one absolute requirement of an
  // opening animation being "presentation only."
  static const _maxWait = Duration(seconds: 4);

  // Fractions of the controller's own 0.0-1.0 value — identical for both
  // `full` and `fast`, since each already carries its own wall-clock
  // duration; only `reduced` skips the painter phase entirely.
  static const _preRevealEnd = 0.55;
  static const _revealStart = 0.42;
  static const _revealEnd = 0.74;
  static const _lockStart = 0.72;
  static const _lockEnd = 0.92;

  AnimationController? _controller;
  Timer? _safetyTimer;
  _SequenceKind? _kind;
  bool _dismissed = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _safetyTimer = Timer(_maxWait, _dismiss);
  }

  // Deliberately a plain field mutation during build(), not a deferred
  // setState — `_startIfReady` runs synchronously at the top of build(),
  // so assigning `_controller`/`_kind` directly here means the very same
  // build pass already renders the freshly-created controller, with no
  // extra frame of lag and no window where a second build (e.g. from an
  // unrelated provider change) could race in and spawn a second,
  // competing controller before the first was ever wired up.
  void _startIfReady(bool reducedMotion, OnboardingStatus onboarding) {
    if (_controller != null || _removed) return;
    if (onboarding is! OnboardingStatusLoaded) return;

    final kind = reducedMotion
        ? _SequenceKind.reduced
        : (onboarding.completed ? _SequenceKind.fast : _SequenceKind.full);
    final duration = switch (kind) {
      _SequenceKind.full => _fullDuration,
      _SequenceKind.fast => _fastDuration,
      _SequenceKind.reduced => _reducedDuration,
    };

    try {
      final controller = AnimationController(vsync: this, duration: duration);
      unawaited(
        controller.forward().whenComplete(() {
          if (mounted) _dismiss();
        }),
      );
      _kind = kind;
      _controller = controller;
    } catch (_) {
      // An animation-layer failure must never block the app itself.
      _dismiss();
    }
  }

  void _dismiss() {
    _safetyTimer?.cancel();
    if (_dismissed || !mounted) return;
    setState(() => _dismissed = true);
    Future.delayed(_fadeOutDuration, () {
      if (mounted) setState(() => _removed = true);
    });
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return widget.child;

    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final onboarding = ref.watch(onboardingStatusProvider);
    _startIfReady(reducedMotion, onboarding);

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final controller = _controller;

    return Stack(
      children: [
        ExcludeSemantics(child: widget.child),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _dismissed ? 0 : 1,
            duration: _fadeOutDuration,
            curve: Curves.easeOut,
            child: ColoredBox(
              color: tokens.background,
              child: SizedBox.expand(
                child: Semantics(
                  label: 'CAN',
                  excludeSemantics: true,
                  child: controller == null
                      ? const SizedBox.shrink()
                      : AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) => _SequenceContent(
                            kind: _kind!,
                            progress: controller.value,
                            tokens: tokens,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SequenceContent extends StatelessWidget {
  const _SequenceContent({
    required this.kind,
    required this.progress,
    required this.tokens,
  });

  final _SequenceKind kind;
  final double progress;
  final ForgeTokens tokens;

  static double _fraction(double t, double start, double end) {
    if (end <= start) return t >= end ? 1 : 0;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (kind == _SequenceKind.reduced) {
      // No orbit/scale/arrow/pulse — a plain fade-in, brief hold, and
      // the overlay's own fade-out handles the exit. Target ~0.4-0.8s
      // total, owned by `_reducedDuration` above.
      final opacity = Curves.easeOut.transform(_fraction(progress, 0.0, 0.5));
      return Opacity(
        opacity: opacity,
        child: CanWordmark(
          revealProgress: 1,
          lockProgress: 0,
          accent: tokens.accent,
          accent2: tokens.accent2,
          textColor: tokens.text,
        ),
      );
    }

    final preReveal = _fraction(
      progress,
      0,
      _CanOpeningOverlayState._preRevealEnd,
    );
    final reveal = _fraction(
      progress,
      _CanOpeningOverlayState._revealStart,
      _CanOpeningOverlayState._revealEnd,
    );
    final lock = _fraction(
      progress,
      _CanOpeningOverlayState._lockStart,
      _CanOpeningOverlayState._lockEnd,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: CanIgnitionPainter(
            progress: preReveal,
            accent: tokens.accent,
            accent2: tokens.accent2,
          ),
        ),
        CanWordmark(
          revealProgress: reveal,
          lockProgress: lock,
          accent: tokens.accent,
          accent2: tokens.accent2,
          textColor: tokens.text,
        ),
      ],
    );
  }
}
