/// Display emphasis only — never affects delivery eligibility (that's
/// [ForgeNotificationType.isServerAuthoritative] + quiet hours +
/// preferences). Achievement/level/competition moments read as [high];
/// routine reminders as [normal].
enum NotificationPriority { normal, high }
