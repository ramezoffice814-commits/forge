import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../../core/backend/backend_mode.dart';
import '../../../../core/backend/backend_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../data/local_notification/local_notification_scheduler.dart';
import '../../data/local_notification/plugin_local_notification_service.dart';
import '../../data/local_notification/unsupported_local_notification_service.dart';
import '../../data/mock/mock_notification_repository.dart';
import '../../data/supabase/supabase_notification_repository.dart';
import '../../domain/enums/forge_notification_type.dart';
import '../../domain/enums/notification_deep_link.dart';
import '../../domain/repositories/local_notification_service.dart';
import '../../domain/repositories/notification_repository.dart';
import '../pages/notification_deep_link_router.dart';

/// Mock in mock backend mode; the real Supabase-backed repository in
/// live/staging mode — mirrors `aiCoachClientProvider`'s exact
/// selection pattern (Roadmap Item 14).
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final mode = ref.watch(backendModeProvider);
  if (mode == BackendMode.mock) {
    return MockNotificationRepository();
  }
  return SupabaseNotificationRepository(supa.Supabase.instance.client);
});

/// Platform gate for OS-level delivery (Roadmap Item 17 section 3): a
/// real, plugin-backed implementation on Android and Windows, an honest
/// no-op everywhere else (Web today — see
/// [UnsupportedLocalNotificationService]'s own doc comment for why Web
/// isn't just wired up the same way). Never selected by
/// [backendModeProvider]/mock-vs-live — OS notification capability is a
/// platform question, not a backend one, and must keep working in mock
/// mode exactly as it does live (spec section 15).
final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows)) {
    return PluginLocalNotificationService();
  }
  return const UnsupportedLocalNotificationService();
});

final localNotificationSchedulerProvider = Provider<LocalNotificationScheduler>(
  (ref) =>
      LocalNotificationScheduler(ref.watch(localNotificationServiceProvider)),
);

/// Initializes the OS notification plugin once per app session and
/// wires notification taps (both a live tap and a cold-start launch) to
/// real navigation — watched once from [ForgeApp] exactly like
/// `aiPrivacyBootstrapProvider` (Roadmap Item 14B/16). Safe to watch
/// unconditionally: [LocalNotificationService.initialize] never throws,
/// even on a platform/build where the plugin can't actually bind (it
/// self-reports as unsupported instead — see
/// [PluginLocalNotificationService]'s own doc comment).
final osNotificationBootstrapProvider = FutureProvider<void>((ref) async {
  final service = ref.read(localNotificationServiceProvider);
  final router = ref.read(appRouterProvider);
  await service.initialize(
    onTap: (payload) => _handleNotificationTap(ref, router, payload),
  );
  final launchPayload = await service.consumeLaunchPayload();
  _handleNotificationTap(ref, router, launchPayload);
});

/// Backs [OsNotificationSettingsTile]'s status display (Roadmap Item 17
/// section 17) — a thin, explicit-refresh wrapper around
/// [LocalNotificationService.permissionStatus]/[requestPermission],
/// following this codebase's usual `Notifier` + manual state pattern
/// rather than a bare `FutureProvider` because the state also needs to
/// update in response to an explicit user action (the "Turn on" button),
/// not just once at construction.
class OsNotificationPermissionController
    extends Notifier<AsyncValue<LocalNotificationPermissionStatus>> {
  @override
  AsyncValue<LocalNotificationPermissionStatus> build() {
    Future.microtask(refresh);
    return const AsyncValue.loading();
  }

  Future<void> refresh() async {
    // Idempotent — PluginLocalNotificationService no-ops once already
    // initialized, so this is safe to await even if ForgeApp's own
    // osNotificationBootstrapProvider watch already triggered it.
    await ref.read(osNotificationBootstrapProvider.future);
    final status = await ref
        .read(localNotificationServiceProvider)
        .permissionStatus();
    state = AsyncValue.data(status);
  }

  Future<void> requestPermission() async {
    final status = await ref
        .read(localNotificationServiceProvider)
        .requestPermission();
    state = AsyncValue.data(status);
  }
}

final osNotificationPermissionControllerProvider =
    NotifierProvider<
      OsNotificationPermissionController,
      AsyncValue<LocalNotificationPermissionStatus>
    >(OsNotificationPermissionController.new);

/// The only place an OS notification's payload becomes navigation
/// (Roadmap Item 17 section 11) — mirrors the in-app inbox's own
/// `navigateToDeepLink` safety rules exactly: [ForgeNotificationType.
/// tryParse] fails safe (`null`) for anything unrecognized, and
/// [NotificationDeepLink.forType] is the same exhaustive, closed mapping
/// Item 15 already established. A payload is only ever the type's own
/// [ForgeNotificationType.wireName] — never a raw route string, and
/// never anything a forged/corrupted payload could turn into arbitrary
/// navigation.
void _handleNotificationTap(Ref ref, GoRouter router, String? payload) {
  if (payload == null) return;
  final type = ForgeNotificationType.tryParse(payload);
  if (type == null) return;
  final destination = NotificationDeepLink.forType(type);
  if (destination == null) return;
  navigateToDeepLinkWithRouter(router, ref.read, destination);
}
