/// Placeholder sync surface for later cloud push/pull.
///
/// MVP keeps SQLite as source of truth; this interface documents the
/// eventual sync engine without implementing network I/O yet.
abstract class SyncEngine {
  Future<void> enqueueLocalChange(String entity, int id);
  Future<SyncStatus> syncNow();
  Stream<SyncStatus> watchStatus();
}

enum SyncStatus {
  idle,
  pending,
  syncing,
  synced,
  error,
}

/// No-op sync — always idle / offline-local.
class StubSyncEngine implements SyncEngine {
  const StubSyncEngine();

  @override
  Future<void> enqueueLocalChange(String entity, int id) async {}

  @override
  Future<SyncStatus> syncNow() async => SyncStatus.idle;

  @override
  Stream<SyncStatus> watchStatus() => Stream.value(SyncStatus.idle);
}
