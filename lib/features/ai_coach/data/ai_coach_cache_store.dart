import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_key_value_store.dart';
import '../domain/entities/ai_coach_response.dart';
import '../domain/enums/ai_coach_suggested_action.dart';
import '../domain/enums/ai_coach_task.dart';

/// Caches AI responses for the tasks worth caching (Roadmap Item 14
/// section 16: mission explanation, Daily Transmission script, weekly
/// recap) — never [AiCoachTask.coachChat], which is free-form
/// conversation and has no stable cache key by design (spec section 16:
/// "do not cache sensitive free-form chat indefinitely without a clear
/// policy" — the policy here is simply "never", the least surprising
/// option). [AiCoachTask.postMissionCoaching] is also never cached: it's
/// only ever generated once, immediately after a genuinely new event.
///
/// The cache key includes [contextVersion] — a caller-supplied
/// fingerprint of whatever made this request's context distinct (e.g.
/// `<userId>:<missionInstanceId>` for a mission explanation,
/// `<userId>:<isoWeek>` for a weekly recap) — so a stale cached response
/// is structurally unreachable once the underlying context changes,
/// never served by accident.
class AiCoachCacheStore {
  const AiCoachCacheStore(this._store);

  final SecureKeyValueStore _store;

  static const _cacheableTasks = {
    AiCoachTask.missionExplanation,
    AiCoachTask.dailyTransmissionDialogue,
    AiCoachTask.weeklyRecap,
  };

  bool isCacheable(AiCoachTask task) => _cacheableTasks.contains(task);

  String _keyFor(AiCoachTask task, String contextVersion) =>
      'forge.ai_coach_cache.${task.name}.$contextVersion';

  Future<AiCoachResponse?> load(AiCoachTask task, String contextVersion) async {
    if (!isCacheable(task)) return null;
    final raw = await _store.read(_keyFor(task, contextVersion));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final message = decoded['message'];
      if (message is! String) return null;
      final actionsRaw = decoded['suggestedActions'];
      final actions = <AiCoachSuggestedAction>[];
      if (actionsRaw is List) {
        for (final entry in actionsRaw) {
          if (entry is String) {
            final parsed = AiCoachSuggestedAction.tryParse(entry);
            if (parsed != null) actions.add(parsed);
          }
        }
      }
      return AiCoachResponse.local(message, suggestedActions: actions);
    } catch (_) {
      // Corrupt cache entry — never crash the caller, just miss.
      return null;
    }
  }

  Future<void> save(
    AiCoachTask task,
    String contextVersion,
    AiCoachResponse response,
  ) async {
    if (!isCacheable(task)) return;
    await _store.write(
      _keyFor(task, contextVersion),
      jsonEncode({
        'message': response.message,
        'suggestedActions': response.suggestedActions
            .map((a) => a.name)
            .toList(),
      }),
    );
  }
}

final aiCoachCacheStoreProvider = Provider<AiCoachCacheStore>((ref) {
  return AiCoachCacheStore(ref.watch(secureKeyValueStoreProvider));
});
