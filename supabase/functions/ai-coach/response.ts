// Response validation + defense-in-depth safety filtering (Roadmap Item
// 14 sections 12 & 14) — mirrors
// lib/features/ai_coach/domain/services/ai_coach_safety_filter.dart's
// unsafe-signal list on the Flutter side. The mock provider's fixed
// templates can never actually trip this (they're authored by us), but
// this check exists here specifically so that wiring a *real* provider
// later inherits it for free rather than needing it added at that point.

import { ProviderResponse } from "./mock_provider.ts";

const MAX_MESSAGE_LENGTH = 2000;

const UNSAFE_SIGNALS = [
  "system prompt",
  "api key",
  "password",
  "service_role",
  "cron secret",
  "your xp has been",
  "your rank is now",
  "you have been promoted",
  "you have been demoted",
];

export function isUnsafe(response: ProviderResponse): boolean {
  const haystack = `${response.message} ${response.reasoningSummary ?? ""}`.toLowerCase();
  return UNSAFE_SIGNALS.some((signal) => haystack.includes(signal));
}

/** Caps message length defensively — the mock provider's templates are
 * always well under this, but a real provider response should never be
 * trusted to self-limit its own output size. */
export function withinSizeLimits(response: ProviderResponse): boolean {
  return response.message.length > 0 && response.message.length <= MAX_MESSAGE_LENGTH;
}
