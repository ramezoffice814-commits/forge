import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/entities/forge_notification.dart';
import '../../domain/services/notification_copy.dart';

/// One inbox row. Read/unread is the only visual distinction (spec
/// section 11) — an accent dot for unread, dimmed text for read; no
/// separate "new" badge system to keep in sync with it.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final ForgeNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final copy = NotificationCopy.resolve(notification);
    final isRead = notification.isRead;

    return Semantics(
      button: true,
      label: '${isRead ? '' : 'Unread. '}${copy.title}. ${copy.body}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: tokens.radius.mdRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: tokens.spacing.space2,
            horizontal: tokens.spacing.space1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 6, right: tokens.spacing.space2),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: isRead ? Colors.transparent : tokens.accent,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                        color: isRead
                            ? tokens.text.withValues(alpha: 0.7)
                            : tokens.text,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.space1 / 2),
                    Text(
                      copy.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: tokens.spacing.space1),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }
}
