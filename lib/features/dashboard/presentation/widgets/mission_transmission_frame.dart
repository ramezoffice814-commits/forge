import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

/// Future states a real character (Rive, later) will drive. Today this
/// widget renders a single abstract placeholder look regardless of state
/// beyond a light tint change — the state enum exists now so
/// [TodayMissionCard] and the eventual character widget share the same
/// contract and swapping in a real character never means redesigning the
/// card around it.
enum TransmissionFrameState {
  incoming,
  idle,
  speaking,
  revealed,
  accepted,
  completed,
  unavailable,
}

/// Abstract, original placeholder for the Daily Transmission's character
/// frame — a soft silhouette built from plain shapes/gradients (no
/// third-party or copyrighted assets), a purple glow, a transmission
/// label, and a subtle scan-line texture. Rive lands in a later roadmap
/// item; this widget's job is only to hold that visual slot.
class MissionTransmissionFrame extends StatelessWidget {
  const MissionTransmissionFrame({super.key, required this.state});

  final TransmissionFrameState state;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final unavailable = state == TransmissionFrameState.unavailable;

    return Semantics(
      label: unavailable
          ? 'Transmission unavailable'
          : 'The Watcher, mission transmission preview',
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: tokens.radius.lgRadius,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.1,
                colors: [
                  tokens.accentRamp.c900.withValues(
                    alpha: unavailable ? 0.3 : 0.9,
                  ),
                  tokens.background,
                ],
              ),
              border: Border.all(
                color: tokens.accent.withValues(
                  alpha: unavailable ? 0.12 : 0.32,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _ExcludedFromSemantics(
                  child: _ScanLines(color: tokens.text.withValues(alpha: 0.04)),
                ),
                _ExcludedFromSemantics(
                  child: _GlowReveal(
                    color: tokens.accent,
                    reduceMotion: reduceMotion,
                    active: !unavailable,
                  ),
                ),
                _ExcludedFromSemantics(
                  child: _Silhouette(
                    color: tokens.accentRamp.c700.withValues(
                      alpha: unavailable ? 0.25 : 0.55,
                    ),
                  ),
                ),
                Positioned(
                  top: tokens.spacing.space3,
                  left: tokens.spacing.space4,
                  child: _TransmissionLabel(
                    active: !unavailable,
                    reduceMotion: reduceMotion,
                  ),
                ),
                if (unavailable)
                  Positioned(
                    bottom: tokens.spacing.space4,
                    child: Text(
                      'UNAVAILABLE OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: tokens.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExcludedFromSemantics extends StatelessWidget {
  const _ExcludedFromSemantics({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: child);
}

class _TransmissionLabel extends StatelessWidget {
  const _TransmissionLabel({required this.active, required this.reduceMotion});

  final bool active;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active)
          _PulsingDot(color: tokens.accent, reduceMotion: reduceMotion)
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tokens.text.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
        SizedBox(width: tokens.spacing.space2),
        Text(
          'TRANSMISSION',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            color: tokens.text.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Deliberately a plain, static dot — not a perpetual pulse. Bottom-nav
/// tabs stay mounted forever under [StatefulShellRoute.indexedStack] (that's
/// the point — it's how tab state survives switching), so anything that
/// animates in a continuous loop here would keep ticking indefinitely even
/// while another tab is on screen: real battery/CPU cost on low-end
/// Android, and it also means `pumpAndSettle` in tests never completes.
/// [_GlowReveal] below plays once and stops for the same reason.
class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.color, required this.reduceMotion});

  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A single reveal animation (fade + scale in) that plays once when the
/// frame first appears, then stops — not a continuous pulse. See
/// [_PulsingDot] for why.
class _GlowReveal extends StatefulWidget {
  const _GlowReveal({
    required this.color,
    required this.reduceMotion,
    required this.active,
  });

  final Color color;
  final bool reduceMotion;
  final bool active;

  @override
  State<_GlowReveal> createState() => _GlowRevealState();
}

class _GlowRevealState extends State<_GlowReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final scale = 0.85 + (curved.value * 0.15);
        return Opacity(
          opacity: (widget.active ? 0.55 : 0.2) * curved.value,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A soft circle + rounded-trapezoid "shoulders" silhouette — entirely
/// geometric, not representing any specific character.
class _Silhouette extends StatelessWidget {
  const _Silhouette({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 150),
      painter: _SilhouettePainter(color),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final headCenter = Offset(size.width / 2, size.height * 0.28);
    canvas.drawCircle(headCenter, size.width * 0.22, paint);

    final shoulders = Path()
      ..moveTo(size.width * 0.5, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.05,
        size.height * 0.55,
        size.width * 0.02,
        size.height,
      )
      ..lineTo(size.width * 0.98, size.height)
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.55,
        size.width * 0.5,
        size.height * 0.42,
      )
      ..close();
    canvas.drawPath(shoulders, paint);
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ScanLines extends StatelessWidget {
  const _ScanLines({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScanLinesPainter(color), size: Size.infinite);
  }
}

class _ScanLinesPainter extends CustomPainter {
  _ScanLinesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinesPainter oldDelegate) =>
      oldDelegate.color != color;
}
