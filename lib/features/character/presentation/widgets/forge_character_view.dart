import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_state.dart';

/// A hooded silhouette with a real purple rim-light stroke and four
/// mood-driven pose variants (idle/speaking/proud/concerned) — dark
/// figure, restrained scan-lines, soft ambient glow. Still built entirely
/// from plain Flutter shapes/gradients (no third-party or copyrighted
/// artwork, no generated image assets — a deliberate zero-cost choice,
/// Mobile Polish Pass 2); a real Rive file or illustrated art remains a
/// possible future upgrade without this widget's contract changing.
///
/// Every transition is an *implicit* animation (`Animated…` widgets) rather
/// than a manually driven, continuously repeating `AnimationController` —
/// so there is never a ticker running once a state has settled, whether
/// this view sits inside the transmission page or a persistently-mounted
/// dashboard tab.
class ForgeCharacterView extends StatelessWidget {
  const ForgeCharacterView({
    super.key,
    required this.profile,
    required this.state,
    this.reducedMotion = false,
    this.speakingIntensity = 0,
    this.aspectRatio = 4 / 5,
  });

  final CharacterProfile profile;
  final CharacterState state;
  final bool reducedMotion;

  /// 0–1. A static level while [state] is [CharacterState.speaking] — not a
  /// live per-frame amplitude — see the "no continuous ticker" note above.
  final double speakingIntensity;
  final double aspectRatio;

  bool get _unavailable => state == CharacterState.unavailable;
  bool get _hidden => state == CharacterState.hidden;

  double get _glowAlpha => switch (state) {
    CharacterState.hidden => 0,
    CharacterState.unavailable => 0.15,
    CharacterState.speaking => 0.55 + (speakingIntensity.clamp(0, 1) * 0.3),
    CharacterState.missionRevealed ||
    CharacterState.missionAccepted ||
    CharacterState.proud ||
    CharacterState.completed => 0.85,
    CharacterState.concerned => 0.45,
    CharacterState.thinking => 0.4,
    _ => 0.55,
  };

  double get _silhouetteAlpha {
    if (_hidden) return 0;
    if (_unavailable) return 0.25;
    return 0.62;
  }

  double get _scale => switch (state) {
    CharacterState.hidden => 0.82,
    CharacterState.incoming || CharacterState.entering => 0.94,
    CharacterState.missionAccepted || CharacterState.proud => 1.03,
    CharacterState.disappearing => 0.9,
    _ => 1.0,
  };

  String get _statusLabel => switch (state) {
    CharacterState.hidden => 'STANDBY',
    CharacterState.unavailable => 'UNAVAILABLE',
    CharacterState.incoming => 'INCOMING',
    CharacterState.entering => 'CONNECTING',
    CharacterState.speaking => 'TRANSMITTING',
    CharacterState.thinking => 'TRANSMITTING',
    CharacterState.missionRevealed => 'MISSION READY',
    _ => 'TRANSMISSION',
  };

  /// Collapses the 13-value [CharacterState] machine down to 4 poses —
  /// same idea `_glowAlpha`/`_scale` above already apply, just for the
  /// silhouette's own posture/rim-light treatment. `hidden`/
  /// `disappearing`/`unavailable` need no dedicated pose: they already
  /// resolve to near-zero `_silhouetteAlpha`, so whichever pose was
  /// last showing simply fades out — `idle` is a safe, neutral base for
  /// them.
  _CharacterMood get _mood => switch (state) {
    CharacterState.speaking ||
    CharacterState.thinking => _CharacterMood.speaking,
    CharacterState.missionAccepted ||
    CharacterState.proud ||
    CharacterState.completed => _CharacterMood.proud,
    CharacterState.concerned => _CharacterMood.concerned,
    _ => _CharacterMood.idle,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return Semantics(
      // Every visual in this widget — including the status label and the
      // offline caption — is decorative; the single label below is the
      // complete accessible description, so descendant semantics (which
      // would otherwise leak the status label's own Text-derived label as a
      // second node) are dropped entirely rather than excluded piecemeal.
      label: _unavailable
          ? '${profile.displayName} unavailable'
          : profile.accessibilityDescription,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: tokens.radius.lgRadius,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.1,
                colors: [
                  tokens.accentRamp.c900.withValues(
                    alpha: _unavailable ? 0.3 : 0.9,
                  ),
                  tokens.background,
                ],
              ),
              border: Border.all(
                color: tokens.accent.withValues(
                  alpha: _unavailable ? 0.12 : 0.32,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _ScanLines(color: tokens.text.withValues(alpha: 0.04)),
                AnimatedOpacity(
                  duration: duration,
                  opacity: _glowAlpha,
                  child: _GlowCircle(color: tokens.accent),
                ),
                AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOut,
                  scale: _scale,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: _silhouetteAlpha,
                    child: AnimatedSwitcher(
                      duration: duration,
                      // A plain cross-fade between two _Silhouette
                      // instances — the mood change itself (posture,
                      // rim-light) is what's worth transitioning, not a
                      // slide/scale on top of it.
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _Silhouette(
                        key: ValueKey(_mood),
                        color: tokens.accentRamp.c700,
                        rimLightColor: tokens.accent,
                        mood: _mood,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: tokens.spacing.space3,
                  left: tokens.spacing.space4,
                  child: _StatusLabel(
                    label: _statusLabel,
                    active: !_unavailable && !_hidden,
                  ),
                ),
                if (_unavailable)
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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? tokens.accent : tokens.text.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: tokens.spacing.space2),
        Text(
          label,
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

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.5), Colors.transparent],
        ),
      ),
    );
  }
}

/// Four poses the hooded silhouette can take, driven by
/// [ForgeCharacterView._mood] — a code-only (zero-cost, Mobile Polish
/// Pass 2) stand-in for real illustrated mood variants: subtle posture
/// changes plus a rim-light intensity shift, not a different picture.
enum _CharacterMood { idle, speaking, proud, concerned }

class _MoodPose {
  const _MoodPose({
    required this.headTiltRadians,
    required this.verticalLift,
    required this.shoulderWidthScale,
    required this.rimLightOpacity,
  });

  /// Positive tilts the head/shoulders slightly up (proud), negative
  /// slightly down (concerned) — applied to the whole figure as one
  /// canvas rotation, not separate head/shoulder transforms, so the
  /// silhouette always reads as one connected figure.
  final double headTiltRadians;

  /// Logical pixels; negative lifts the figure (proud), positive settles
  /// it (concerned).
  final double verticalLift;
  final double shoulderWidthScale;
  final double rimLightOpacity;
}

const Map<_CharacterMood, _MoodPose> _moodPoses = {
  _CharacterMood.idle: _MoodPose(
    headTiltRadians: 0,
    verticalLift: 0,
    shoulderWidthScale: 1,
    rimLightOpacity: 0.5,
  ),
  _CharacterMood.speaking: _MoodPose(
    headTiltRadians: 0,
    verticalLift: 0,
    shoulderWidthScale: 1,
    rimLightOpacity: 0.78,
  ),
  _CharacterMood.proud: _MoodPose(
    headTiltRadians: 0.05,
    verticalLift: -4,
    shoulderWidthScale: 1.08,
    rimLightOpacity: 0.95,
  ),
  _CharacterMood.concerned: _MoodPose(
    headTiltRadians: -0.06,
    verticalLift: 3,
    shoulderWidthScale: 0.92,
    rimLightOpacity: 0.3,
  ),
};

/// A hooded figure — peaked hood, not a plain circle — plus
/// rounded-trapezoid shoulders, entirely geometric and not representing
/// any specific real person or character. [rimLightColor] is stroked
/// along one edge only (a linear-gradient-shaded stroke, bright on the
/// right fading to nothing on the left) so it reads as a light source,
/// matching [CharacterProfile.accessibilityDescription]'s "soft purple
/// rim light," not just a flat-colored outline.
class _Silhouette extends StatelessWidget {
  const _Silhouette({
    super.key,
    required this.color,
    required this.rimLightColor,
    required this.mood,
  });

  final Color color;
  final Color rimLightColor;
  final _CharacterMood mood;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 150),
      painter: _SilhouettePainter(color, rimLightColor, _moodPoses[mood]!),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.color, this.rimLightColor, this.pose);

  final Color color;
  final Color rimLightColor;
  final _MoodPose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy + pose.verticalLift);
    canvas.rotate(pose.headTiltRadians);
    canvas.translate(-center.dx, -center.dy);

    final fill = Paint()..color = color;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          rimLightColor.withValues(alpha: pose.rimLightOpacity),
          rimLightColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final headCenter = Offset(size.width / 2, size.height * 0.28);
    final headRadius = size.width * 0.22;
    final hood = Path()
      ..moveTo(headCenter.dx, headCenter.dy - headRadius * 1.15)
      ..quadraticBezierTo(
        headCenter.dx - headRadius * 1.05,
        headCenter.dy - headRadius * 0.6,
        headCenter.dx - headRadius,
        headCenter.dy + headRadius * 0.15,
      )
      ..quadraticBezierTo(
        headCenter.dx - headRadius * 0.9,
        headCenter.dy + headRadius * 0.95,
        headCenter.dx,
        headCenter.dy + headRadius * 1.05,
      )
      ..quadraticBezierTo(
        headCenter.dx + headRadius * 0.9,
        headCenter.dy + headRadius * 0.95,
        headCenter.dx + headRadius,
        headCenter.dy + headRadius * 0.15,
      )
      ..quadraticBezierTo(
        headCenter.dx + headRadius * 1.05,
        headCenter.dy - headRadius * 0.6,
        headCenter.dx,
        headCenter.dy - headRadius * 1.15,
      )
      ..close();
    canvas.drawPath(hood, fill);
    canvas.drawPath(hood, rim);

    final shoulderHalfWidth = size.width * 0.48 * pose.shoulderWidthScale;
    final shoulderCenterX = size.width * 0.5;
    final shoulders = Path()
      ..moveTo(shoulderCenterX, size.height * 0.42)
      ..quadraticBezierTo(
        shoulderCenterX - shoulderHalfWidth * 0.94,
        size.height * 0.55,
        shoulderCenterX - shoulderHalfWidth,
        size.height,
      )
      ..lineTo(shoulderCenterX + shoulderHalfWidth, size.height)
      ..quadraticBezierTo(
        shoulderCenterX + shoulderHalfWidth * 0.94,
        size.height * 0.55,
        shoulderCenterX,
        size.height * 0.42,
      )
      ..close();
    canvas.drawPath(shoulders, fill);
    canvas.drawPath(shoulders, rim);

    // Speaking's one extra detail: a small glow bar where a voice would
    // be — static, not pulsing (the "no continuous ticker" rule this
    // file already follows; AnimatedSwitcher's cross-fade is what makes
    // it appear/disappear).
    if (pose == _moodPoses[_CharacterMood.speaking]) {
      final voiceGlow = Paint()
        ..color = rimLightColor.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(headCenter.dx, headCenter.dy + headRadius * 0.55),
            width: headRadius * 0.5,
            height: 3,
          ),
          const Radius.circular(2),
        ),
        voiceGlow,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.rimLightColor != rimLightColor ||
      oldDelegate.pose != pose;
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
