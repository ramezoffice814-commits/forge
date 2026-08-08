/// Coarse-grained dashboard failures — enough to pick the right recoverable
/// -vs-unrecoverable UI state, nothing more.
sealed class DashboardFailure {
  const DashboardFailure();
}

class DashboardNetworkFailure extends DashboardFailure {
  const DashboardNetworkFailure();
}

/// Offline with nothing cached to fall back to — distinct from
/// [DashboardNetworkFailure] because the UI needs a different state
/// entirely (there's no stale data to show), not just a retry banner.
class DashboardOfflineFailure extends DashboardFailure {
  const DashboardOfflineFailure();
}

class DashboardUnknownFailure extends DashboardFailure {
  const DashboardUnknownFailure();
}

class DashboardException implements Exception {
  const DashboardException(this.failure);

  final DashboardFailure failure;

  @override
  String toString() => 'DashboardException(${failure.runtimeType})';
}
