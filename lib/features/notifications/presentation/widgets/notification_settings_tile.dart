import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/quiet_hours.dart';
import '../providers/notification_preferences_controller.dart';

/// The user-facing control over notification categories and quiet hours
/// (Roadmap Item 15 section 10). Deliberately a separate card from
/// [AiPrivacySettingsTile] in [ProfilePage] — notification preferences and
/// AI context privacy are unrelated concerns, per the spec's explicit
/// instruction not to couple them.
class NotificationSettingsTile extends ConsumerWidget {
  const NotificationSettingsTile({super.key});

  static const _categoryLabels = {
    _Category.dailyMission: 'Daily mission reminder',
    _Category.dailyTransmission: 'Daily transmission reminder',
    _Category.missionFollowup: 'Mission follow-up',
    _Category.achievement: 'Achievements',
    _Category.progression: 'Level-ups',
    _Category.weeklyRecap: 'Weekly recap',
    _Category.competitionResult: 'Competition results',
    _Category.reEngagement: 'Occasional check-ins',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final preferences = ref.watch(notificationPreferencesControllerProvider);
    final notifier = ref.read(
      notificationPreferencesControllerProvider.notifier,
    );

    Future<void> apply(
      NotificationPreferences Function(NotificationPreferences current) update,
    ) {
      return notifier.update(update(preferences));
    }

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spacing.space1),
          // Same reasoning as `AiPrivacySettingsTile`: `ForgeCard`'s own
          // background isn't a `Material`, so the switches/list tiles below
          // need one to paint their ink/selection states into.
          Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'All notifications',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    'Turn off to silence everything below',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.withValues(alpha: 0.6),
                    ),
                  ),
                  value: preferences.masterEnabled,
                  onChanged: (value) =>
                      unawaited(apply((p) => p.copyWith(masterEnabled: value))),
                ),
                if (preferences.masterEnabled) ...[
                  const Divider(),
                  for (final category in _Category.values)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        _categoryLabels[category]!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: category.enabledIn(preferences),
                      onChanged: (value) =>
                          unawaited(apply((p) => category.applyTo(p, value))),
                    ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Quiet hours',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'Pause delivery during a time window you choose',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.text.withValues(alpha: 0.6),
                      ),
                    ),
                    value: preferences.quietHours.enabled,
                    onChanged: (value) => unawaited(
                      apply(
                        (p) => p.copyWith(
                          quietHours: QuietHours(
                            enabled: value,
                            startMinute: p.quietHours.startMinute,
                            endMinute: p.quietHours.endMinute,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (preferences.quietHours.enabled)
                    Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.space1),
                      child: Row(
                        children: [
                          Expanded(
                            child: _QuietHourTimeButton(
                              label: 'Start',
                              minuteOfDay: preferences.quietHours.startMinute,
                              onPicked: (minute) => unawaited(
                                apply(
                                  (p) => p.copyWith(
                                    quietHours: QuietHours(
                                      enabled: true,
                                      startMinute: minute,
                                      endMinute: p.quietHours.endMinute,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: tokens.spacing.space2),
                          Expanded(
                            child: _QuietHourTimeButton(
                              label: 'End',
                              minuteOfDay: preferences.quietHours.endMinute,
                              onPicked: (minute) => unawaited(
                                apply(
                                  (p) => p.copyWith(
                                    quietHours: QuietHours(
                                      enabled: true,
                                      startMinute: p.quietHours.startMinute,
                                      endMinute: minute,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Category {
  dailyMission,
  dailyTransmission,
  missionFollowup,
  achievement,
  progression,
  weeklyRecap,
  competitionResult,
  reEngagement;

  bool enabledIn(NotificationPreferences p) => switch (this) {
    _Category.dailyMission => p.dailyMissionEnabled,
    _Category.dailyTransmission => p.dailyTransmissionEnabled,
    _Category.missionFollowup => p.missionFollowupEnabled,
    _Category.achievement => p.achievementEnabled,
    _Category.progression => p.progressionEnabled,
    _Category.weeklyRecap => p.weeklyRecapEnabled,
    _Category.competitionResult => p.competitionResultEnabled,
    _Category.reEngagement => p.reEngagementEnabled,
  };

  NotificationPreferences applyTo(
    NotificationPreferences p,
    bool value,
  ) => switch (this) {
    _Category.dailyMission => p.copyWith(dailyMissionEnabled: value),
    _Category.dailyTransmission => p.copyWith(dailyTransmissionEnabled: value),
    _Category.missionFollowup => p.copyWith(missionFollowupEnabled: value),
    _Category.achievement => p.copyWith(achievementEnabled: value),
    _Category.progression => p.copyWith(progressionEnabled: value),
    _Category.weeklyRecap => p.copyWith(weeklyRecapEnabled: value),
    _Category.competitionResult => p.copyWith(competitionResultEnabled: value),
    _Category.reEngagement => p.copyWith(reEngagementEnabled: value),
  };
}

class _QuietHourTimeButton extends StatelessWidget {
  const _QuietHourTimeButton({
    required this.label,
    required this.minuteOfDay,
    required this.onPicked,
  });

  final String label;
  final int minuteOfDay;
  final ValueChanged<int> onPicked;

  @override
  Widget build(BuildContext context) {
    final timeOfDay = TimeOfDay(
      hour: minuteOfDay ~/ 60,
      minute: minuteOfDay % 60,
    );
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: timeOfDay,
        );
        if (picked != null) onPicked(picked.hour * 60 + picked.minute);
      },
      child: Text('$label: ${timeOfDay.format(context)}'),
    );
  }
}
