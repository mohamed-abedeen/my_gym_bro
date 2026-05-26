import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/sync_queue_dao.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background sync service — pushes pending changes to Supabase when online.
class SyncService {

  SyncService(this._db, this._supabase) : _dao = SyncQueueDao(_db);
  final AppDatabase _db;
  final SupabaseClient? _supabase;
  final SyncQueueDao _dao;
  bool _isSyncing = false;

  static const _maxRetries = 3;

  /// Attempt to sync all pending queue items to Supabase.
  Future<void> syncAll() async {
    if (_supabase == null) return;
    if (_isSyncing) return; // Prevent concurrent syncs

    _isSyncing = true;
    try {
      // Check connectivity first
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResults.isNotEmpty &&
          !connectivityResults.contains(ConnectivityResult.none);
      if (!hasConnection) return;

      final pending = await _dao.getPending();

      for (final item in pending) {
        var success = false;
        for (var attempt = 1; attempt <= _maxRetries; attempt++) {
          try {
            final result = await _syncItem(item);
            switch (result) {
              case _SyncResult.synced:
                success = true;
                await _dao.markSynced(item.localId);
                break;
              case _SyncResult.deferred:
                // remote_id not yet available — leave in queue for next pass.
                debugPrint(
                  'Sync: deferred item ${item.localId} '
                  '(${item.operation} on ${item.syncTableName}) '
                  '— remote_id pending, will retry on next sync pass',
                );
                success = true; // don't retry this pass, but don't mark synced
                break;
            }
            if (success) break;
          } on Exception catch (e) {
            CrashReporter.recordError(
                e,
                stackTrace: StackTrace.current,
                reason: 'Sync: attempt $attempt/$_maxRetries failed for item ${item.localId}',
              );
            if (attempt < _maxRetries) {
              // Exponential backoff: 1s, 2s, 4s
              await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
            }
          }
        }
      }

      // Clean up synced entries
      await _dao.clearSynced();
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single queue item.
  ///
  /// Returns [_SyncResult.synced] when the Supabase call succeeded, or
  /// [_SyncResult.deferred] when the row's `remote_id` is not yet available
  /// (i.e. the initial insert hasn't synced yet) — the item is left in the
  /// queue so the next [syncAll] pass can pick it up.
  Future<_SyncResult> _syncItem(SyncQueueData item) async {
    final payload = jsonDecode(item.payload) as Map<String, dynamic>;
    final table = item.syncTableName;

    switch (item.operation) {
      case 'insert':
        await _supabase!.from(table).insert(payload);
        return _SyncResult.synced;
      case 'update':
        final remoteId = await _resolveRemoteId(payload, table, item.rowId);
        if (remoteId == null) return _SyncResult.deferred;
        payload['remote_id'] = remoteId;
        await _supabase!.from(table).update(payload).eq('id', remoteId);
        return _SyncResult.synced;
      case 'delete':
        final remoteId = await _resolveRemoteId(payload, table, item.rowId);
        if (remoteId == null) return _SyncResult.deferred;
        await _supabase!.from(table).delete().eq('id', remoteId);
        return _SyncResult.synced;
      default:
        CrashReporter.recordError(
          'Unknown sync operation: "${item.operation}"',
          reason: 'Sync: unrecognized operation for item ${item.localId}',
        );
        return _SyncResult.synced; // discard unknown ops
    }
  }

  /// Try to obtain the `remote_id` for a queued update/delete.
  ///
  /// 1. Use the value already in the payload if present.
  /// 2. Otherwise, look up the row in the local DB — the initial insert may
  ///    have completed and written the `remote_id` back since this queue item
  ///    was created.
  /// 3. If the row still has no `remote_id`, return null so the caller can
  ///    defer the operation.
  Future<String?> _resolveRemoteId(
    Map<String, dynamic> payload,
    String table,
    int rowId,
  ) async {
    // Fast path: already in the payload.
    final existing = payload['remote_id'] as String?;
    if (existing != null) return existing;

    // Slow path: query the local DB for the row's current remote_id.
    try {
      final row = await _db.customSelect(
        'SELECT remote_id FROM $table WHERE local_id = ?',
        variables: [Variable<int>(rowId)],
      ).getSingleOrNull();
      return row?.read<String?>('remote_id');
    } on Exception catch (e) {
      debugPrint('Sync: failed to resolve remote_id for $table/$rowId: $e');
      return null;
    }
  }

  /// Enqueue a change for later sync.
  Future<void> enqueue({
    required String table,
    required int rowId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _dao.enqueue(SyncQueueCompanion(
      syncTableName: Value(table),
      rowId: Value(rowId),
      operation: Value(operation),
      payload: Value(jsonEncode(payload)),
      createdAt: Value(DateTime.now()),
    ));

    // Fire-and-forget: callers await enqueue only to persist the queue row.
    // Blocking on syncAll here would make UI flows (e.g. finishSession) wait
    // on a network round-trip before the "Workout complete" screen appears.
    unawaited(syncAll());
  }
}

/// Internal result type for [SyncService._syncItem].
enum _SyncResult {
  /// The item was successfully pushed to Supabase and should be marked synced.
  synced,

  /// The item could not be synced because its `remote_id` is not yet available.
  /// It will be left in the queue for the next sync pass.
  deferred,
}
