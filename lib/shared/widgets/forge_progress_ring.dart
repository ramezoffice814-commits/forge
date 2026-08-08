import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';

/// Ported from the Home/Progress screens' circular rings: a `neutral-800`
/// track, a rounded-cap progress stroke (gradient `accent-300` →
/// `accent-600`), starting at 12 o'clock. [progress] is clamped to 0–1.
class ForgeProgressRing extends StatelessWidget {
  const ForgeProgressRing({
    super.key,
    required this.progress,
    this.size = 180,
    this.strokeWidth = 14,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1),
          strokeWidth: strokeWidth,
          trackColor: tokens.neutralRamp.c800,
          startColor: tokens.accentRamp.c300,
          endColor: tokens.accentRamp.c600,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color startColor;
  final Color endColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [startColor, endColor],
        transform: const _StartAtTop(),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        strokeWidth != oldDelegate.strokeWidth ||
        trackColor != oldDelegate.trackColor ||
        startColor != oldDelegate.startColor ||
        endColor != oldDelegate.endColor;
  }
}

/// Rotates the [SweepGradient] to start at 12 o'clock, matching
/// [Canvas.drawArc]'s `-pi/2` start angle used above.
class _StartAtTop extends GradientTransform {
  const _StartAtTop();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final center = bounds.center;
    return Matrix4.translationValues(center.dx, center.dy, 0) *
        Matrix4.rotationZ(-math.pi / 2) *
        Matrix4.translationValues(-center.dx, -center.dy, 0);
  }
}
