// The only provider actually wired in this pass (Roadmap Item 14 section
// 33: "report cost estimates before using any paid provider" — no real
// provider is configured, so there is nothing to cost-estimate yet).
// Deterministic and context-aware, mirroring
// lib/features/ai_coach/data/mock/mock_ai_coach_client.dart's philosophy
// on the Flutter side: same input always produces the same output, no
// network call, nothing to fail unpredictably.

import { AiCoachContext } from "./context.ts";
import { PromptTemplate } from "./prompt_templates.ts";

export interface ProviderResponse {
  message: string;
  reasoningSummary?: string;
  suggestedActions?: string[];
}

function toneOpener(tone: string): string {
  switch (tone) {
    case "direct":
      return "Straight talk:";
    case "energetic":
      return "Let's go —";
    case "strategic":
      return "Here's the read:";
    case "calm":
    default:
      return "Steady now.";
  }
}

export function generateMockResponse(
  task: string,
  context: AiCoachContext,
  _template: PromptTemplate,
): ProviderResponse {
  const opener = toneOpener(context.coachingTone);

  switch (task) {
    case "missionExplanation":
      return {
        message: context.currentMissionTitle
          ? `${opener} "${context.currentMissionTitle}" fits where you are right now — ${context.consistencySummary}.`
          : `${opener} today's mission was chosen to match where you are right now — ${context.consistencySummary}.`,
        suggestedActions: ["explainMission"],
      };

    case "dailyTransmissionDialogue":
      return {
        message: context.isRecoveryMode
          ? `${opener} take today easy. Recovery is still the work.`
          : `${opener} ${context.activeDaysThisWeek} active days this week. Keep the thread going.`,
      };

    case "postMissionCoaching":
      return {
        message: `${opener} that's done. ${context.consistencySummary}, and that's what counts.`,
        suggestedActions: ["openProgress"],
      };

    case "weeklyRecap":
      return {
        message: `${opener} this week: ${context.consistencySummary}, ${context.activeDaysThisWeek} active days. Level ${context.currentLevel}, ${context.currentTitle}.`,
        suggestedActions: ["openProgress", "openLeaderboard"],
      };

    case "coachChat":
    default:
      return {
        message: context.userMessage
          ? `${opener} on "${context.userMessage}" — ${context.consistencySummary}, so trust the pace you're at.`
          : `${opener} what's on your mind today?`,
      };
  }
}
