import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_scaffold.dart';
import '../../../ai_coach/presentation/widgets/ai_privacy_settings_tile.dart';
import '../../../notifications/presentation/widgets/notification_settings_tile.dart';
import '../../../notifications/presentation/widgets/os_notification_settings_tile.dart';
import '../widgets/settings_about_section.dart';
import '../widgets/settings_accessibility_section.dart';
import '../widgets/settings_account_section.dart';

/// Roadmap Item 16: the single Settings surface that centralizes every
/// user-controlled preference and account control, replacing the
/// scattered "just bolt it onto Profile" approach Items 14/15 used
/// (there was nowhere else to put them yet). Reached from Profile's
/// app bar; a full-screen route pushed on top of the shell, matching
/// `NotificationInboxPage`/`SocialPage`'s own "doesn't need the bottom
/// nav" reasoning.
///
/// Deliberately does not introduce a second AI-privacy or notification-
/// preference model — [AiPrivacySettingsTile] and
/// [NotificationSettingsTile] are the exact same widgets Profile used
/// to host, moved here unchanged, still reading/writing the same
/// [aiPrivacyLevelProvider]/`NotificationPreferencesController` state.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return ForgeScaffold(
      appBarTitle: 'Settings',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ForgeCard(
              elevation: ForgeCardElevation.md,
              children: [SettingsAccountSection()],
            ),
            SizedBox(height: tokens.spacing.space3),
            const ForgeCard(
              elevation: ForgeCardElevation.md,
              children: [AiPrivacySettingsTile()],
            ),
            SizedBox(height: tokens.spacing.space3),
            const ForgeCard(
              elevation: ForgeCardElevation.md,
              children: [
                NotificationSettingsTile(),
                Divider(),
                OsNotificationSettingsTile(),
              ],
            ),
            SizedBox(height: tokens.spacing.space3),
            const ForgeCard(
              elevation: ForgeCardElevation.md,
              children: [SettingsAccessibilitySection()],
            ),
            SizedBox(height: tokens.spacing.space3),
            const ForgeCard(
              elevation: ForgeCardElevation.md,
              children: [SettingsAboutSection()],
            ),
          ],
        ),
      ),
    );
  }
}
