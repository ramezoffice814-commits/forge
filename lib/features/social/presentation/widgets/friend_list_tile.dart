import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/entities/public_profile.dart';

/// One row in the friends list. Renders only [PublicProfile]'s own
/// public-safe fields — there is nothing more sensitive it could show,
/// since the entity itself carries nothing else (see its privacy doc
/// comment).
class FriendListTile extends StatelessWidget {
  const FriendListTile({
    super.key,
    required this.profile,
    this.onTap,
    this.onRemove,
  });

  final PublicProfile profile;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Semantics(
      button: onTap != null,
      label:
          '${profile.displayName}, level ${profile.level}, '
          '${profile.title}, ${profile.league} League',
      child: InkWell(
        onTap: onTap,
        borderRadius: tokens.radius.mdRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.space2),
          child: Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: tokens.neutralRamp.c800,
                  child: Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName[0].toUpperCase()
                        : '?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.space3),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Level ${profile.level} · ${profile.league} League',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.text.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: 'Remove friend',
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
