import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus exposing a simple online/offline
/// signal. "Online" here means "has a network interface up" (wifi/cellular/
/// ethernet), not "internet actually reachable" — a flaky or captive-portal
/// network still attempts the remote call and falls back to the offline
/// outbox on failure, same as any other transient error.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Current online/offline snapshot.
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  /// Emits on every connectivity change, distinct-only so listeners like an
  /// outbox-flush trigger don't re-fire for the same state twice in a row.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
