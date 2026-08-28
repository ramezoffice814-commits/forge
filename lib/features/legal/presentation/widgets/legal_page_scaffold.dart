import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_scaffold.dart';

/// Shared shell for [PrivacyPolicyPage]/[TermsOfServicePage] (Roadmap
/// Item 19 section 17-18) — every legal surface gets the same prominent,
/// impossible-to-miss "pending legal review" banner, so a reader (or a
/// future contributor skimming the widget tree) can never mistake this
/// content for a finished, approved policy. Reachable from both
/// authenticated and unauthenticated routes (see `app_routes.dart` —
/// these two paths are deliberately not in `AppRoutePaths.protected`),
/// matching how a real Terms/Privacy page always needs to be readable
/// before someone creates an account, not just after.
class LegalPageScaffold extends StatelessWidget {
  const LegalPageScaffold({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    // No dedicated "warning" design token exists yet — reuses the same
    // Material error color SettingsAccountSection's delete-account
    // control already does for exactly this "pay attention" purpose.
    final warningColor = Theme.of(context).colorScheme.error;

    return ForgeScaffold(
      appBarTitle: title,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label:
                  'This document is a draft, pending legal review — not '
                  'yet approved as an official policy',
              excludeSemantics: true,
              child: Container(
                padding: EdgeInsets.all(tokens.spacing.space3),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                  border: Border.all(
                    color: warningColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gavel_outlined, color: warningColor, size: 20),
                    SizedBox(width: tokens.spacing.space2),
                    Expanded(
                      child: Text(
                        'Draft — pending legal review. This page describes '
                        "Forge's actual current technical behavior as "
                        'accurately as possible, but it has not been '
                        'reviewed or approved by legal counsel and is not '
                        'yet a final, binding policy.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.space3),
            Text(
              'Draft last updated: $lastUpdated',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.text.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: tokens.spacing.space3),
            for (final section in sections) ...[
              ForgeCard(
                elevation: ForgeCardElevation.md,
                children: [
                  Padding(
                    padding: EdgeInsets.all(tokens.spacing.space2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.heading,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SizedBox(height: tokens.spacing.space1),
                        Text(
                          section.body,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.space3),
            ],
          ],
        ),
      ),
    );
  }
}

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}
