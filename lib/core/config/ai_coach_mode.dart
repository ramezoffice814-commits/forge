/// Whether AI Coach talks to a real provider — independent of
/// [BackendMode] (`lib/core/backend/backend_mode.dart`). The public beta
/// always runs `BackendMode.mock` (zero-cost, no Supabase project
/// required to install), so tying AI Coach's liveness to the overall
/// backend mode would mean it could never go live without flipping
/// missions/XP/competition/social to the real backend too — a much
/// bigger, riskier step than "make AI Coach real." This enum is the
/// separate axis that lets AI Coach alone reach a real (staging or
/// production) Supabase project while everything else stays exactly as
/// it is today.
enum AiCoachMode { mock, live }

/// Resolves [AiCoachMode] from [AppConfig.aiCoachLiveFlag] and whether
/// Supabase is actually configured. Unlike
/// `assertBackendModeConfigIsSafe`, an unconfigured "live" request never
/// throws — it silently degrades to [AiCoachMode.mock]. That asymmetry
/// is deliberate: AI Coach going live is an opt-in, low-stakes request
/// (worst case, a user gets mock coaching text instead of real); the
/// backend guard's release-build refusal exists to catch a genuinely
/// dangerous case (shipping a real backend nobody meant to enable), which
/// this isn't.
AiCoachMode resolveAiCoachMode({
  required bool aiCoachLiveFlag,
  required bool isSupabaseConfigured,
}) {
  if (aiCoachLiveFlag && isSupabaseConfigured) {
    return AiCoachMode.live;
  }
  return AiCoachMode.mock;
}
