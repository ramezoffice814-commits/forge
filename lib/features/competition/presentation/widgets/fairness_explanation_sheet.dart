import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

/// "How ranking works" (spec section 27) — plain language, no raw weights,
/// but never opaque either. Every bullet here maps to a real fairness rule
/// enforced in `ForgeCompetitiveScorePolicy`/`CompetitionCapPolicy`.
class FairnessExplanationSheet extends StatelessWidget {
  const FairnessExplanationSheet({super.key});

  static const _points = [
    'Your current week matters most — lifetime XP does not determine your '
        'rank.',
    'Repeating the same easy mission has reduced competitive value.',
    'Staying active across the week helps more than one big day.',
    'Recovery missions are protected — they count, but never dominate.',
    'Your weekly competitive score resets every week; only your placement '
        'carries forward.',
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => const FairnessExplanationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.space4,
          0,
          tokens.spacing.space4,
          tokens.spacing.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How ranking works',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: tokens.spacing.space3),
            for (final point in _points) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: Theme.of(context).textTheme.bodyMedium),
                  Expanded(
                    child: Text(
                      point,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.space2),
            ],
          ],
        ),
      ),
    );
  }
}
