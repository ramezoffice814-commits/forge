import 'package:flutter/foundation.dart';

import 'entities/dashboard_overview.dart';

/// Envelope around [DashboardOverview] carrying transport-level metadata
/// (currently just "this came from an offline cache") that doesn't belong
/// on the overview itself — mixing "is this stale/cached" into the
/// business data would blur what the repository is answering.
@immutable
class DashboardOverviewResult {
  const DashboardOverviewResult({
    required this.overview,
    this.isOfflineCache = false,
  });

  final DashboardOverview overview;
  final bool isOfflineCache;
}

/// `null` return means "no dashboard data exists yet" (the empty state) —
/// distinct from a brand-new user, who still has a real (zeroed) overview.
abstract class DashboardRepository {
  Future<DashboardOverviewResult?> getOverview();
}
