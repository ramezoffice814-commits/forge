import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_tag.dart';
import '../../../notifications/presentation/providers/notification_inbox_controller.dart';
import '../../../notifications/presentation/providers/notification_inbox_state.dart';
import '../../domain/entities/dashboard_overview.dart';

/// Premium top header: greeting + name, title/class tag, avatar, and the
/// notification bell (Roadmap Item 15) — an unread badge, opening
/// `NotificationInboxPage`. Every piece of text comes from [overview] —
/// nothing here is a hardcoded user name.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key, required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        Builder(
          builder: (context) {
            final inboxState = ref.watch(notificationInboxControllerProvider);
            final unreadCount = inboxState is NotificationInboxReady
                ? inboxState.unreadCount
                : 0;
            return Semantics(
              button: true,
              label: unreadCount > 0
                  ? 'Notifications, $unreadCount unread'
                  : 'Notifications',
              excludeSemantics: true,
              child: Tooltip(
                message: 'Notifications',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () =>
                          context.pushNamed(AppRouteNames.notifications),
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        color: tokens.text.withValues(alpha: 0.8),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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
