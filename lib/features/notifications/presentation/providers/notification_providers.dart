import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../../core/backend/backend_mode.dart';
import '../../../../core/backend/backend_providers.dart';
import '../../data/mock/mock_notification_repository.dart';
import '../../data/supabase/supabase_notification_repository.dart';
import '../../domain/repositories/notification_repository.dart';

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
