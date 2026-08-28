import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';

/// Purely cosmetic, inline (never a blocking modal) celebration banner —
/// dismissible, announces itself once for screen readers, and never
/// autoplays sound. [reducedMotion] collapses the entrance animation to a
/// single frame rather than skipping the celebration entirely.
class LevelUpCelebration extends StatefulWidget {
  const LevelUpCelebration({
    super.key,
    required this.levelNumber,
    required this.levelTitle,
    required this.onDismiss,
    this.reducedMotion = false,
  });

  final int levelNumber;
  final String levelTitle;
  final VoidCallback onDismiss;
  final bool reducedMotion;

  @override
  State<LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

class _LevelUpCelebrationState extends State<LevelUpCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 350),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    // A single, bounded run — never looping, never re-triggering itself.
    _controller.forward();
    // Roadmap Item 21: one restrained haptic pulse for a major-action
    // moment (level up), matching the same "never re-triggering" shape
    // as the animation itself — no platform permission required
    // (HapticFeedback is a core Flutter API), silently a no-op on
    // platforms/devices without haptic support.
    HapticFeedback.mediumImpact();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Level up. You reached level ${widget.levelNumber}, '
        '${widget.levelTitle}.',
        TextDirection.ltr,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return ScaleTransition(
      scale: _scale,
      child: Semantics(
        container: true,
        child: ForgeCard(
          elevation: ForgeCardElevation.lg,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: tokens.accent),
                    SizedBox(width: tokens.spacing.space2),
                    Text(
                      'Level Up',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Dismiss',
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            Text(
              'Level ${widget.levelNumber} — ${widget.levelTitle}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
