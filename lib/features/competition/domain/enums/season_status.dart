/// A season's lifecycle — deliberately explicit rather than derived
/// implicitly from `now` vs. `startsAt`/`endsAt` at every call site, so a
/// season can be archived (past `endsAt` but still queryable for Hall of
/// Fame) without every reader having to reimplement that distinction.
enum SeasonStatus { upcoming, active, completed, archived }
