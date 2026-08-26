import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_providers.dart';
import '../../../auth/presentation/auth_state.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../../missions/domain/aggregates/mission_lifecycle_state.dart'
    as lifecycle;
import '../../../missions/presentation/providers/mission_lifecycle_controller.dart';
import '../../../missions/presentation/providers/mission_lifecycle_state.dart';
import '../../../missions/presentation/providers/resolved_mission_instance_controller.dart';
import '../../data/local_reminder_store.dart';
import '../../domain/entities/forge_notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/services/local_reminder_engine.dart';
import 'notification_inbox_state.dart';
import 'notification_preferences_controller.dart';
import 'notification_providers.dart';

/// The single authoritative notification inbox session — mirrors
/// `ProgressionController`'s shape exactly (a `ready` future, a
/// `Notifier<State>`, auth-driven rebuild/clear on sign-out so no
/// session's notifications survive into the next — Roadmap Item 15
/// sections 10/18/25).
///
/// Merges two genuinely different sources into one list (spec section
/// 11's single inbox UX): server-authoritative rows (achievement/level/
/// competition, fetched via [NotificationRepository]) and client-owned
/// local reminders (daily mission/transmission/follow-up, computed live
/// from [resolvedMissionInstanceProvider] and mission lifecycle state
/// via [LocalReminderEngine] — never fetched, never invented).
class NotificationInboxController extends Notifier<NotificationInboxState> {
  final Completer<void> _readyCompleter = Completer<void>();
  bool _disposed = false;

  Future<void> get ready => _readyCompleter.future;

  @override
  NotificationInboxState build() {
    ref.onDispose(() => _disposed = true);
    final authStatus = ref.watch(
      authStateNotifierProvider.select((s) => s.status),
    );
    if (authStatus != AuthStatus.authenticated) {
      // Nothing from a previous session survives a sign-out — the next
      // build() (once a real sign-in happens) starts clean. Also cancels
      // any OS-level reminders scheduled for whoever just signed out
      // (Roadmap Item 17 section 14: account-switch isolation) — safe
      // to call even when nothing is scheduled.
      Future.microtask(
        () =>
            ref.read(localNotificationSchedulerProvider).cancelAllForSignOut(),
      );
      return const NotificationInboxLoading();
    }
    // `ref.listen`, deliberately not `ref.watch`: a preference change
    // (e.g. the user turns off "Achievements" in settings) must trigger
    // a fresh `_load()` so the inbox re-filters, but must NOT make that
    // change count as this controller's own rebuild — `watch` would
    // reset `state` back to Loading on every preferences change (and
    // `NotificationPreferences` has no value equality, so even its own
    // harmless default-then-loaded bootstrap transition would count),
    // flickering the inbox back to a spinner for no visible reason.
    // `listen` runs `_load()` as a side effect while leaving whatever
    // `state` currently holds untouched until that fresh load resolves.
    ref.listen(notificationPreferencesControllerProvider, (previous, next) {
      Future.microtask(_load);
    });
    Future.microtask(_load);
    return const NotificationInboxLoading();
  }

  Future<void> _load() async {
    // The server fetch gets its own try/catch, deliberately separate
    // from everything below: client-owned local reminders and their
    // OS-level presentation (Roadmap Item 17) must keep working
    // regardless of whether the server is reachable (spec section 15 —
    // "do not require backend connectivity merely to fire a local
    // reminder"), but a fetch failure must still surface the exact same
    // retryable error state this already did before Item 17 (see the
    // offline/reconnect tests) — never silently swallowed just because
    // the local half succeeded.
    List<ForgeNotification>? serverList;
    Object? fetchError;
    try {
      final repository = ref.read(notificationRepositoryProvider);
      serverList = await repository.fetchInbox();
    } catch (e) {
      fetchError = e;
    }
    if (_disposed) return;

    try {
      await ref.read(notificationPreferencesControllerProvider.notifier).ready;
      if (_disposed) return;
      final preferences = ref.read(notificationPreferencesControllerProvider);
      final localList = await _computeLocalReminders(preferences);
      if (_disposed) return;

      await ref
          .read(localNotificationSchedulerProvider)
          .presentDueReminders(localList);

      if (fetchError != null) {
        state = const NotificationInboxError(
          "Couldn't load notifications right now.",
        );
        return;
      }

      // Category/master preferences are the single place they actually
      // take effect for server-authoritative rows (spec section 10) —
      // local reminders are already gated at creation time, so this is a
      // no-op for those, not a second, possibly-inconsistent filter.
      //
      // Quiet hours are deliberately NOT applied here: they gate the
      // three client-owned reminder types at creation time in
      // LocalReminderEngine. Server-authoritative rows aren't mirrored
      // to an OS notification in this pass (Roadmap Item 17 report),
      // and the inbox itself is pull-based: opening it is an explicit
      // user action, not something quiet hours is meant to defer.
      final combined =
          [
              ...serverList!,
              ...localList,
            ].where((n) => preferences.allows(n.type)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = NotificationInboxReady(combined);
    } catch (_) {
      if (_disposed) return;
      state = const NotificationInboxError(
        "Couldn't load notifications right now.",
      );
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<List<ForgeNotification>> _computeLocalReminders(
    NotificationPreferences preferences,
  ) async {
    final resolved = ref.read(resolvedMissionInstanceProvider);
    if (resolved == null) return const [];

    // Reminder "last shown" state must never be shared across accounts on
    // the same device (spec section 10) — see LocalReminderStore's own
    // doc comment for why this can't just be the bare dedup key.
    final userId = ref.read(currentBackendUserIdProvider);
    if (userId == null) return const [];

    final store = ref.read(localReminderStoreProvider);
    final now = DateTime.now();
    final lifecycleState = ref.read(
      missionLifecycleControllerProvider(resolved.instance.instanceId),
    );

    final isAcceptedOrLater =
        lifecycleState is MissionLifecycleReady &&
        lifecycleState.aggregate.lifecycleState !=
            lifecycle.MissionLifecycleState.assigned &&
        lifecycleState.aggregate.lifecycleState !=
            lifecycle.MissionLifecycleState.viewed;
    final isCompleted =
        lifecycleState is MissionLifecycleReady &&
        lifecycleState.aggregate.lifecycleState ==
            lifecycle.MissionLifecycleState.completed;
    final acceptedAt = lifecycleState is MissionLifecycleReady
        ? lifecycleState.aggregate.acceptedAt
        : null;

    final results = <ForgeNotification>[];

    final dailyMissionKey = 'daily_mission:${_dateKey(now)}';
    final dailyMission = LocalReminderEngine.dailyMissionReminder(
      preferences: preferences,
      localNow: now,
      lastShownAt: await store.lastShownAt(userId, dailyMissionKey),
      missionInstanceId: resolved.instance.instanceId,
      missionTitle: resolved.instance.title,
      missionAlreadyAccepted: isAcceptedOrLater,
    );
    if (dailyMission != null) {
      results.add(dailyMission);
      await store.recordShown(userId, dailyMission.dedupKey, now);
    }

    final dailyTransmissionKey = 'daily_transmission:${_dateKey(now)}';
    final dailyTransmission = LocalReminderEngine.dailyTransmissionReminder(
      preferences: preferences,
      localNow: now,
      lastShownAt: await store.lastShownAt(userId, dailyTransmissionKey),
      transmissionAlreadyAvailableToUser: true,
      missionAlreadyAccepted: isAcceptedOrLater,
    );
    if (dailyTransmission != null) {
      results.add(dailyTransmission);
      await store.recordShown(userId, dailyTransmission.dedupKey, now);
    }

    if (isAcceptedOrLater && !isCompleted && acceptedAt != null) {
      final followupKey = 'mission_followup:${resolved.instance.instanceId}';
      final followup = LocalReminderEngine.missionFollowupReminder(
        preferences: preferences,
        localNow: now,
        lastShownAt: await store.lastShownAt(userId, followupKey),
        acceptedAt: acceptedAt,
        missionInstanceId: resolved.instance.instanceId,
        missionTitle: resolved.instance.title,
        missionCompleted: isCompleted,
      );
      if (followup != null) {
        results.add(followup);
        await store.recordShown(userId, followup.dedupKey, now);
      }
    }

    // Genuine future-dated OS scheduling for Mission Follow-up —
    // distinct from the "is it due right now" live check above (spec
    // section 8/9: real advance scheduling, deferred out of quiet
    // hours). Runs every time this recomputes (sign-in, dashboard view,
    // preference change), so accepting/completing a mission naturally
    // reschedules or cancels the prior OS alarm via its stable id.
    await ref
        .read(localNotificationSchedulerProvider)
        .syncMissionFollowup(
          missionInstanceId: resolved.instance.instanceId,
          missionTitle: resolved.instance.title,
          acceptedAt: isAcceptedOrLater ? acceptedAt : null,
          missionCompleted: isCompleted,
          categoryEnabled: preferences.missionFollowupEnabled,
          masterEnabled: preferences.masterEnabled,
          quietHours: preferences.quietHours,
        );

    return results;
  }

  Future<void> markRead(ForgeNotification notification) async {
    final current = state;
    if (current is! NotificationInboxReady) return;

    state = NotificationInboxReady([
      for (final n in current.notifications)
        if (n.id == notification.id) n.copyWith(readAt: DateTime.now()) else n,
    ]);

    if (notification.type.isServerAuthoritative) {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
    }
    // Local reminders: read-state is session-only (the dedup/cooldown
    // that already governs whether they reappear lives in
    // LocalReminderStore, recorded when the reminder was computed —
    // there is nothing further to persist here).
  }

  Future<void> markAllRead() async {
    final current = state;
    if (current is! NotificationInboxReady) return;

    final now = DateTime.now();
    state = NotificationInboxReady([
      for (final n in current.notifications)
        n.isRead ? n : n.copyWith(readAt: now),
    ]);

    if (current.notifications.any(
      (n) => n.type.isServerAuthoritative && !n.isRead,
    )) {
      await ref.read(notificationRepositoryProvider).markAllRead();
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final notificationInboxControllerProvider =
    NotifierProvider<NotificationInboxController, NotificationInboxState>(
      NotificationInboxController.new,
    );
