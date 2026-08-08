import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/entities/character_profile.dart';
import '../controllers/daily_transmission_state.dart';

String transmissionPhaseLabel(TransmissionPhase phase) {
  return switch (phase) {
    TransmissionPhase.unavailable => 'Unavailable',
    TransmissionPhase.preparing => 'Preparing…',
    TransmissionPhase.incoming => 'Incoming Transmission',
    TransmissionPhase.entering => 'Connecting…',
    TransmissionPhase.speaking => 'Transmitting',
    TransmissionPhase.missionReveal => 'Mission Revealed',
    TransmissionPhase.awaitingAcceptance => 'Awaiting Your Decision',
    TransmissionPhase.accepting => 'Accepting…',
    TransmissionPhase.accepted => 'Mission Accepted',
    TransmissionPhase.replaying => 'Replaying…',
    TransmissionPhase.skipped => 'Mission Revealed',
    TransmissionPhase.error => 'Transmission Error',
  };
}

/// Top bar for the Daily Transmission page: character identity, a live
/// phase label (a `Semantics.liveRegion` so screen readers announce phase
/// changes), and the close control.
class TransmissionStatusHeader extends StatelessWidget {
  const TransmissionStatusHeader({
    super.key,
    required this.profile,
    required this.phase,
    required this.onClose,
  });

  final CharacterProfile profile;
  final TransmissionPhase phase;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      children: [
        Tooltip(
          message: 'Close transmission',
          child: Semantics(
            button: true,
            label: 'Close transmission',
            excludeSemantics: true,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              iconSize: 22,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  transmissionPhaseLabel(phase),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.text.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
