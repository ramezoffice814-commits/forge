/// Where a participant currently sits within their league group's ranked
/// list — used both for [LeaderboardEntry] display and as the
/// [LeagueMovementPolicy] zone. Never a guarantee: "in the promotion zone"
/// only becomes a real movement once the week closes.
enum PromotionStatus { promotionZone, safeZone, demotionZone }
