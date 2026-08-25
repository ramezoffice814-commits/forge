import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_state.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../domain/entities/notification_preferences.dart';
import 'notification_providers.dart';

/// The one place [NotificationPreferences] is read from/written to —
/// mirrors `aiPrivacyBootstrapProvider`'s "default synchronously, load
/// the real value in the background" shape, but as a full `Notifier`
/// (not a bare `StateProvider`) since this also owns persisting writes,
/// not just applying one loaded value.
class NotificationPreferencesController extends Notifier<NotificationPreferences> {
  final Completer<void> _readyCompleter = Completer<void>();
  bool _disposed = false;

  Future<void> get ready => _readyCompleter.future;

  @override
  NotificationPreferences build() {
    ref.onDispose(() => _disposed = true);
    final authStatus = ref.watch(authStateNotifierProvider.select((s) => s.status));
    if (authStatus != AuthStatus.authenticated) {
      // Signed out: fall back to defaults rather than leaking the
      // previous user's choices into whatever screen reads this next
      // (spec section 10: "account switching must not leak
      // preferences").
      return const NotificationPreferences();
    }
    Future.microtask(_load);
    return const NotificationPreferences();
  }

  Future<void> _load() async {
    try {
      final loaded = await ref.read(notificationRepositoryProvider).getPreferences();
      if (_disposed) return;
      state = loaded;
    } catch (_) {
      // Preferences are advisory, never load-bearing for correctness —
      // keep the safe defaults already in state rather than surfacing
      // an error state for a settings screen nobody has opened yet.
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> update(NotificationPreferences preferences) async {
    state = preferences;
    await ref.read(notificationRepositoryProvider).updatePreferences(preferences);
  }
}

final notificationPreferencesControllerProvider =
    NotifierProvider<NotificationPreferencesController, NotificationPreferences>(
      NotificationPreferencesController.new,
    );
