import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

/// Shared layout for every onboarding screen: an icon-in-a-circle
/// placeholder (no cinematic character assets exist yet — this is a
/// tasteful stand-in, swappable later), a kicker, a title, and body copy.
class OnboardingPageTemplate extends StatelessWidget {
  const OnboardingPageTemplate({
    super.key,
    required this.icon,
    required this.kicker,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String kicker;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.accentRamp.c800,
            ),
            child: Icon(icon, size: 44, color: tokens.accentRamp.c100),
          ),
          SizedBox(height: tokens.spacing.space6),
          Text(
            kicker,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: tokens.spacing.space2),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          SizedBox(height: tokens.spacing.space3),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.text.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
