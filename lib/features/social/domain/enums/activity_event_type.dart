/// Every kind of activity the social feed can show — deliberately a short,
/// closed list of genuinely shareable, public-safe milestones. Never add a
/// type here that could imply something private (a specific mission, a
/// recovery/health signal, a reflection).
enum ActivityEventType {
  achievementUnlocked,
  levelReached,
  competitionMilestone,
}
