import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_button.dart';

/// The full control surface for the Daily Transmission experience — every
/// control from the spec's list lives here so there is exactly one place
/// that wires them up. Icon buttons keep Flutter's default 48dp touch
/// target (above the 44dp minimum); disabled controls stay visible (not
/// hidden) so their availability is always legible.
class TransmissionControls extends StatelessWidget {
  const TransmissionControls({
    super.key,
    required this.canReplay,
    required this.canSkip,
    required this.canAccept,
    required this.muted,
    required this.missionAccepted,
    required this.onReplay,
    required this.onSkip,
    required this.onToggleMute,
    required this.onTranscript,
  });

  final bool canReplay;
  final bool canSkip;
  final bool canAccept;
  final bool muted;
  final bool missionAccepted;

  final VoidCallback? onReplay;
  final VoidCallback? onSkip;
  final VoidCallback onToggleMute;
  final VoidCallback onTranscript;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlIcon(
          tooltip: canReplay ? 'Replay transmission' : 'Replay unavailable yet',
          icon: Icons.replay_rounded,
          onPressed: canReplay ? onReplay : null,
        ),
        _ControlIcon(
          tooltip: canSkip ? 'Skip to mission' : 'Skip unavailable',
          icon: Icons.skip_next_rounded,
          onPressed: canSkip ? onSkip : null,
        ),
        _ControlIcon(
          tooltip: muted ? 'Unmute' : 'Mute',
          icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          onPressed: onToggleMute,
        ),
        _ControlIcon(
          tooltip: 'View transcript',
          icon: Icons.subject_rounded,
          onPressed: onTranscript,
        ),
      ],
    );
  }
}

class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            color: tokens.accent,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
      ),
    );
  }
}

/// The primary "Accept Mission" call to action — separated from
/// [TransmissionControls] because it's a full-width [ForgeButton], not an
/// icon, and its enabled state has different semantics (the mission flow's
/// main action rather than a playback control).
class AcceptMissionButton extends StatelessWidget {
  const AcceptMissionButton({
    super.key,
    required this.canAccept,
    required this.missionAccepted,
    required this.onAccept,
  });

  final bool canAccept;
  final bool missionAccepted;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return ForgeButton(
      label: missionAccepted ? 'Mission Accepted' : 'Accept Mission',
      onPressed: canAccept ? onAccept : null,
    );
  }
}
