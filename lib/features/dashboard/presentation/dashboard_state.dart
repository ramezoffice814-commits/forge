import 'package:flutter/foundation.dart';

import '../domain/dashboard_failure.dart';
import '../domain/entities/dashboard_overview.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

/// Covers the normal, new-user ("first authenticated session" — a
/// zeroed-out overview rather than a separate state class, see
/// `currentDay == 0`), recovery, and completed-mission scenarios — they're
/// all "we have an overview to show", just with different field values.
/// [isOfflineCache] is the one thing that's a genuinely different
/// *transport* condition worth a flag rather than a whole new state.
@immutable
class DashboardPopulated extends DashboardState {
  const DashboardPopulated(this.overview, {this.isOfflineCache = false});

  final DashboardOverview overview;
  final bool isOfflineCache;
}

/// No dashboard data exists yet (distinct from a new user, who still has a
/// real zeroed overview).
class DashboardEmpty extends DashboardState {
  const DashboardEmpty();
}

/// Offline with nothing cached to fall back to.
class DashboardOfflineNoCache extends DashboardState {
  const DashboardOfflineNoCache();
}

@immutable
class DashboardErrorState extends DashboardState {
  const DashboardErrorState(this.failure, {required this.recoverable});

  final DashboardFailure failure;
  final bool recoverable;
}
