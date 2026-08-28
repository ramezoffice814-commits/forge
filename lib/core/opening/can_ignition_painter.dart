import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws the pre-wordmark cinematic beats of the CAN opening sequence
/// (Roadmap Item 21) — ignition, orbiting arcs, and the diagonal arrow
/// stroke — as one continuous, parametrized painter rather than three
/// separate widgets, so their glow/blur layers can share one [Canvas]
/// without stacking multiple `BackdropFilter`-style costs.
///
/// [progress] is a single 0.0-1.0 value covering the whole pre-reveal
/// portion of the sequence; sub-phase timing is expressed as fractions of
/// it below rather than as wall-clock durations, so the caller owns all
/// actual timing (full vs. fast-path vs. reduced-motion) and this painter
/// stays a pure function of `progress`.
class CanIgnitionPainter extends CustomPainter {
  const CanIgnitionPainter({
    required this.progress,
    required this.accent,
    required this.accent2,
  });

  final double progress;
  final Color accent;
  final Color accent2;

  // Sub-phase fractions of `progress` (0.0-1.0), tuned to roughly mirror
  // the spec's ignition -> orbit -> arrow beats without hardcoding actual
  // milliseconds here.
  static const _ignitionEnd = 0.22;
  static const _orbitStart = 0.12;
  static const _orbitEnd = 0.62;
  static const _arrowStart = 0.48;
  static const _arrowEnd = 0.92;

  static double _localT(double t, double start, double end) {
    if (end <= start) return t >= end ? 1 : 0;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = math.min(size.width, size.height) * 0.5;

    _paintIgnition(canvas, center, baseRadius);
    _paintOrbit(canvas, center, baseRadius);
    _paintArrow(canvas, center, baseRadius);
  }

  void _paintIgnition(Canvas canvas, Offset center, double baseRadius) {
    final t = _localT(progress, 0, _ignitionEnd);
    if (t <= 0) return;
    // Ignition itself fades slightly once the orbit takes over, so it
    // reads as a single point flaring rather than a static circle sitting
    // underneath everything else for the whole sequence.
    final settle = 1 - (_localT(progress, _ignitionEnd, _orbitEnd) * 0.55);
    final radius = baseRadius * 0.22 * Curves.easeOutCubic.transform(t);
    final opacity = Curves.easeOut.transform(t) * settle;
    if (radius <= 0 || opacity <= 0) return;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent2.withValues(alpha: opacity * 0.9),
          accent.withValues(alpha: opacity * 0.35),
          accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 2.6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius * 2.6, glowPaint);

    final corePaint = Paint()
      ..color = accent2.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.4, corePaint);
  }

  void _paintOrbit(Canvas canvas, Offset center, double baseRadius) {
    final t = _localT(progress, _orbitStart, _orbitEnd);
    if (t <= 0) return;
    final fadeOut = 1 - _localT(progress, _arrowEnd, 1.0);
    final sweep = 2 * math.pi * Curves.easeInOutCubic.transform(t);

    void arc({
      required double radiusFactor,
      required double strokeWidth,
      required double startAngle,
      required double opacity,
      required Color color,
    }) {
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * fadeOut)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius * radiusFactor),
        startAngle,
        sweep,
        false,
        paint,
      );
    }

    arc(
      radiusFactor: 0.62,
      strokeWidth: 2.4,
      startAngle: -math.pi / 2,
      opacity: 0.85,
      color: accent2,
    );
    // Second, fainter arc trailing the first — starts a beat later so it
    // never fully catches up, reading as depth rather than a duplicate.
    final trailT = _localT(progress, _orbitStart + 0.06, _orbitEnd);
    arc(
      radiusFactor: 0.78,
      strokeWidth: 1.6,
      startAngle: -math.pi / 2,
      opacity: 0.4 * trailT,
      color: accent,
    );
  }

  void _paintArrow(Canvas canvas, Offset center, double baseRadius) {
    final t = _localT(progress, _arrowStart, _arrowEnd);
    if (t <= 0) return;
    final fadeOut = 1 - _localT(progress, _arrowEnd, 1.0);
    final reveal = Curves.easeOutCubic.transform(t);

    // A short diagonal stroke, lower-left to upper-right, matching the
    // mark's own upward energy stroke — traced progressively via
    // PathMetric rather than redrawn as a growing straight line, so a
    // future curved variant only needs to change `path`, not the reveal
    // logic below it.
    final start = center + Offset(-baseRadius * 0.34, baseRadius * 0.3);
    final end = center + Offset(baseRadius * 0.4, -baseRadius * 0.46);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final tracedLength = metric.length * reveal;
    final traced = metric.extractPath(0, tracedLength);

    final glowPaint = Paint()
      ..color = accent2.withValues(alpha: 0.5 * fadeOut)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(traced, glowPaint);

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92 * fadeOut)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(traced, strokePaint);

    // Arrowhead only once the stroke has mostly landed, as a short pulse
    // rather than a shape dragged along the whole path.
    final headT = _localT(progress, _arrowStart + 0.32, _arrowEnd);
    if (headT > 0) {
      final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
      final headSize = baseRadius * 0.09 * Curves.easeOutBack.transform(headT);
      final left = end + Offset.fromDirection(angle + math.pi * 0.78, headSize);
      final right =
          end + Offset.fromDirection(angle - math.pi * 0.78, headSize);
      final headPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.92 * fadeOut)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(left.dx, left.dy)
          ..lineTo(end.dx, end.dy)
          ..lineTo(right.dx, right.dy),
        headPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CanIgnitionPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.accent2 != accent2;
}
