// Versioned prompt templates (Roadmap Item 14 section 19: "prompt
// versioning" — a version id travels with every generated response via
// observability so a future prompt change is traceable). Each template
// turns (task, sanitized context, persona) into the system/user prompt
// pair a real provider call would send. No template here is ever sent
// to a provider yet (see mock_provider.ts — this pass wires no real,
// paid provider) but the shape is exactly what wiring one later would
// consume, so switching providers only touches mock_provider.ts.

import { AiCoachContext } from "./context.ts";
import { WATCHER_PERSONA } from "./persona.ts";

export interface PromptTemplate {
  version: string;
  systemPrompt: string;
  userPrompt: string;
}

const TASK_VERSIONS: Record<string, string> = {
  missionExplanation: "mission_explanation_v1",
  dailyTransmissionDialogue: "daily_transmission_v1",
  postMissionCoaching: "post_mission_coaching_v1",
  weeklyRecap: "weekly_recap_v1",
  coachChat: "coach_chat_v1",
};

function systemPrompt(): string {
  return [
    `You are ${WATCHER_PERSONA.name}, a coaching presence in a discipline app.`,
    `Tone: ${WATCHER_PERSONA.tone.join(", ")}.`,
    `Values: ${WATCHER_PERSONA.values.join("; ")}.`,
    `Never: ${WATCHER_PERSONA.forbiddenBehaviors.join("; ")}.`,
    `Keep dialogue to at most ${WATCHER_PERSONA.maxDialogueLines} short lines.`,
    "You never state or imply XP, level, rank, league, or any numeric " +
      "outcome as something you decide — those are always server-confirmed " +
      "facts handed to you, never yours to grant or predict.",
  ].join(" ");
}

function userPromptFor(task: string, context: AiCoachContext): string {
  const facts = [
    `User: ${context.displayName}, level ${context.currentLevel} (${context.currentTitle}).`,
    `Consistency: ${context.consistencySummary}.`,
    context.isRecoveryMode ? "Currently in a recovery period." : null,
    context.currentMissionTitle
      ? `Current mission: "${context.currentMissionTitle}" (${context.currentMissionCategory ?? "uncategorized"}, ${context.currentMissionDifficulty ?? "unspecified difficulty"}).`
      : null,
    `Available time today: ${context.availableMinutesToday} minutes.`,
    context.goalFocusLabel ? `Goal focus: ${context.goalFocusLabel}.` : null,
    context.userMessage ? `User asked: "${context.userMessage}"` : null,
  ].filter((line): line is string => line !== null);

  const taskInstruction: Record<string, string> = {
    missionExplanation: "Explain why today's mission fits this user, briefly.",
    dailyTransmissionDialogue: "Write a short opening/closing line for today's check-in.",
    postMissionCoaching: "Give a brief, honest reflection on the mission just completed.",
    weeklyRecap: "Summarize this week's pattern in a few encouraging, honest sentences.",
    coachChat: "Reply to the user's message in character, briefly.",
  };

  return [...facts, taskInstruction[task] ?? "Respond briefly, in character."].join("\n");
}

export function buildPrompt(task: string, context: AiCoachContext): PromptTemplate {
  return {
    version: TASK_VERSIONS[task] ?? "unknown_v0",
    systemPrompt: systemPrompt(),
    userPrompt: userPromptFor(task, context),
  };
}
