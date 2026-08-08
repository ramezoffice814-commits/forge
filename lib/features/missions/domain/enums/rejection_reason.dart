/// Why a user declined an assigned mission. Feeds future selection (see
/// `MissionVarietyPolicy`/`MissionSelectionController.rejectMission`) as a
/// soft signal — one rejection nudges scoring, it never permanently bans a
/// category or mission.
enum RejectionReason {
  tooDifficult,
  tooLong,
  wrongCategory,
  inaccessible,
  unsafe,
  notRelevant,
  notInMood,
  other,
}
