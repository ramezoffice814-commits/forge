import 'package:flutter/material.dart';

/// The "C A N" reveal + halo-lock beat (Roadmap Item 21, opening sequence
/// phases 4-5). Deliberately plain [Text] letters styled through the
/// existing theme rather than a custom glyph path — there is no approved
/// vector source for the CAN mark in this codebase to trace (see
/// docs/CAN_REBRAND_AUDIT.md's icon-source status), so the wordmark
/// leans on the app's own established typography instead of guessing at
/// the real mark's letterforms.
///
/// [revealProgress] drives opacity/scale per letter (fade + scale from
/// ~0.96 -> 1.0, not a typed-in-order reveal — "A" resolves slightly
/// after "C"/"N" so it reads as the visual focal point, per spec).
/// [lockProgress] drives one controlled halo pulse once the mark has
/// landed; 0 before the lock phase begins.
class CanWordmark extends StatelessWidget {
  const CanWordmark({
    super.key,
    required this.revealProgress,
    required this.lockProgress,
    required this.accent,
    required this.accent2,
    required this.textColor,
  });

  final double revealProgress;
  final double lockProgress;
  final Color accent;
  final Color accent2;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayMedium?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 6,
      height: 1,
    );

    // One controlled pulse — scales briefly past 1.0 then eases back,
    // never repeating (spec: "no repeated flashing").
    final pulse = lockProgress <= 0
        ? 0.0
        : Curves.easeOut.transform(
            lockProgress < 0.5 ? lockProgress * 2 : (1 - lockProgress) * 2,
          );

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse > 0)
            Container(
              width: 220 + (pulse * 60),
              height: 220 + (pulse * 60),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent2.withValues(alpha: pulse * 0.28),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Letter('C', revealProgress, 0.0, style, accent2),
              const SizedBox(width: 4),
              _Letter('A', revealProgress, 0.18, style, accent),
              const SizedBox(width: 4),
              _Letter('N', revealProgress, 0.06, style, accent2),
            ],
          ),
        ],
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter(this.char, this.progress, this.delay, this.style, this.glow);

  final String char;
  final double progress;
  final double delay;
  final TextStyle? style;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    // Each letter gets its own short window within the overall reveal so
    // they don't all pop in perfectly synchronized — `delay` shifts that
    // window later, "A" furthest, matching the spec's focal-point intent.
    const windowSpan = 0.7;
    final localT = ((progress - delay) / windowSpan).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(localT);

    return Opacity(
      opacity: eased,
      child: Transform.scale(
        scale: 0.96 + (0.04 * eased),
        child: Text(
          char,
          style: style?.copyWith(
            shadows: [
              Shadow(color: glow.withValues(alpha: 0.5), blurRadius: 18),
            ],
          ),
        ),
      ),
    );
  }
}
