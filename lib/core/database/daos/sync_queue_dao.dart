import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'sync_queue_dao.g.dart';

/// Data access object for the offline [SyncQueue] table.
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Get all un-synced entries.
  Future<List<SyncQueueData>> getPending() =>
      (select(syncQueue)..where((t) => t.isSynced.equals(false))).get();

  /// Stream count of pending sync items.
  Stream<int> watchPendingCount() {
    final countExp = syncQueue.localId.count();
    final query = selectOnly(syncQueue)
      ..addColumns([countExp])
      ..where(syncQueue.isSynced.equals(false));
    return query.watchSingle().map((row) => row.read(countExp)!);
  }

  /// Enqueue a sync operation.
  Future<int> enqueue(SyncQueueCompanion companion) =>
      into(syncQueue).insert(companion);

  /// Mark an entry as synced.
  Future<void> markSynced(int localId) =>
      (update(syncQueue)..where((t) => t.localId.equals(localId)))
          .write(const SyncQueueCompanion(isSynced: Value(true)));

  /// Remove all synced entries.
  Future<int> clearSynced() =>
      (delete(syncQueue)..where((t) => t.isSynced.equals(true))).go();
}
