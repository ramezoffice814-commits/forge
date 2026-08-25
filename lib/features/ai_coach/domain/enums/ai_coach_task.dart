/// Every AI generation task Forge supports — closed on purpose (spec
/// section 19: "versioned prompt templates"), so a new task is always a
/// deliberate addition to both this enum and its matching prompt version,
/// never a string a caller can invent inline.
enum AiCoachTask {
  missionExplanation,
  dailyTransmissionDialogue,
  postMissionCoaching,
  weeklyRecap,
  coachChat,
}
