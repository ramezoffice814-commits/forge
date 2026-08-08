import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_tag.dart';
import '../../domain/entities/dashboard_overview.dart';

/// Premium top header: greeting + name, title/class tag, avatar, and a
/// (not-yet-wired) notification action. Every piece of text comes from
/// [overview] — nothing here is a hardcoded user name.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final initials = _initials(overview.displayName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: '${overview.displayName}\'s avatar',
          image: true,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: tokens.accentRamp.c800,
            child: Text(
              initials,
              style: TextStyle(
                color: tokens.accentRamp.c100,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                overview.greeting,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.withValues(alpha: 0.6),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      overview.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.space2),
                  ForgeTag(
                    label: overview.title,
                    variant: ForgeTagVariant.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Notifications',
          child: Tooltip(
            message: 'Notifications (coming soon)',
            child: IconButton(
              onPressed: null,
              icon: Icon(
                Icons.notifications_none_rounded,
                color: tokens.text.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
