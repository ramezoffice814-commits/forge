// Real, free-tier AI provider (Roadmap Item 14C). Plain `fetch` against
// Gemini's generateContent REST endpoint — no SDK dependency, matching
// this project's existing esm.sh-only, no-heavy-dependency style. Never
// imported by mock_provider.ts or vice versa; index.ts is the only place
// that picks between them (see AI_PROVIDER env var there).
//
// The API key lives only as this Edge Function's own environment secret
// (GEMINI_API_KEY) — it is never sent to, stored in, or reachable from
// the Flutter client, matching every other Forge trust boundary (see
// SupabaseAiCoachClient's own doc comment on the Flutter side).
//
// Throws on any failure (network error, non-2xx, empty/unparseable
// reply) rather than returning a partial/guessed response — index.ts is
// responsible for catching that and falling back to generateMockResponse
// so a provider outage never surfaces as an error to the user.

import { AiCoachContext } from "./context.ts";
import { PromptTemplate } from "./prompt_templates.ts";
import { Provider, ProviderResponse } from "./provider.ts";

// Free-tier flash-lite model — re-confirmed against
// https://ai.google.dev/gemini-api/docs/models and .../pricing
// immediately before the first forge-staging deploy (2026-09-07): the
// 1.5 series originally targeted here no longer exists at all — the
// lineup moved to a 3.x generation. "Flash-Lite" variants are marketed
// specifically as the cost/high-throughput-optimized tier, which is the
// right fit for this app's short coaching messages and correlates with
// the most generous free-tier daily quota in practice — re-verify this
// choice again before ever raising AI_COACH_DAILY_CAP materially, since
// free-tier model availability/naming has already shifted once.
const DEFAULT_MODEL = "gemini-3.5-flash-lite";

// Mirrors mock_provider.ts's own per-task suggested actions exactly —
// these are UI affordances tied to `task`, not something a text
// generation call should be asked to invent or that should vary by
// model output.
const SUGGESTED_ACTIONS: Record<string, string[]> = {
  missionExplanation: ["explainMission"],
  postMissionCoaching: ["openProgress"],
  weeklyRecap: ["openProgress", "openLeaderboard"],
};

interface GeminiCandidate {
  content?: { parts?: { text?: string }[] };
}

interface GeminiGenerateContentResponse {
  candidates?: GeminiCandidate[];
}

export class GeminiProvider implements Provider {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly fetchFn: typeof fetch;

  constructor(options: {
    apiKey: string;
    model?: string;
    fetchFn?: typeof fetch;
  }) {
    this.apiKey = options.apiKey;
    this.model = options.model ?? DEFAULT_MODEL;
    this.fetchFn = options.fetchFn ?? fetch;
  }

  async generate(
    task: string,
    _context: AiCoachContext,
    template: PromptTemplate,
  ): Promise<ProviderResponse> {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;

    const res = await this.fetchFn(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: template.userPrompt }] }],
        systemInstruction: { parts: [{ text: template.systemPrompt }] },
      }),
    });

    if (!res.ok) {
      throw new Error(`Gemini request failed: HTTP ${res.status}`);
    }

    const body = (await res.json()) as GeminiGenerateContentResponse;
    const text = body.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text || text.trim().length === 0) {
      throw new Error("Gemini response had no usable text.");
    }

    return {
      message: text.trim(),
      suggestedActions: SUGGESTED_ACTIONS[task],
    };
  }
}
