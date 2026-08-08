import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_state.dart';

/// Original, abstract presentation of a Forge character — dark silhouette,
/// purple rim light, restrained scan-lines, soft ambient glow. Built from
/// plain Flutter shapes/gradients only (no third-party or copyrighted
/// artwork); a real Rive file replaces the painters here in a later
/// roadmap item without this widget's contract changing.
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
                    child: _Silhouette(color: tokens.accentRamp.c700),
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

/// A soft circle + rounded-trapezoid "shoulders" silhouette — entirely
/// geometric, not representing any specific real person or character.
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
