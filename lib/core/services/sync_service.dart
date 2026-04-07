import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/sync_queue_dao.dart';

/// Background sync service — pushes pending changes to Supabase when online.
class SyncService {
  final AppDatabase _db;
  final SupabaseClient? _supabase;
  bool _isSyncing = false;

  static const _maxRetries = 3;

  SyncService(this._db, this._supabase);

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

      final dao = SyncQueueDao(_db);
      final pending = await dao.getPending();

      for (final item in pending) {
        bool success = false;
        for (int attempt = 1; attempt <= _maxRetries; attempt++) {
          try {
            success = await _syncItem(item);
            if (success) {
              await dao.markSynced(item.localId);
              break;
            } else {
              // Operation skipped (e.g., no remoteId) — don't retry
              debugPrint('Sync: skipped item ${item.localId} (${item.operation} on ${item.syncTableName}) — no remote_id');
              break;
            }
          } catch (e) {
            debugPrint('Sync: attempt $attempt/$_maxRetries failed for item ${item.localId}: $e');
            if (attempt < _maxRetries) {
              // Exponential backoff: 1s, 2s, 4s
              await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
            }
          }
        }
      }

      // Clean up synced entries
      await dao.clearSynced();
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single queue item. Returns true if synced, false if skipped.
  Future<bool> _syncItem(SyncQueueData item) async {
    final payload = jsonDecode(item.payload) as Map<String, dynamic>;
    final table = item.syncTableName;

    switch (item.operation) {
      case 'insert':
        await _supabase!.from(table).insert(payload);
        return true;
      case 'update':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return false;
        await _supabase!.from(table).update(payload).eq('id', remoteId);
        return true;
      case 'delete':
        final remoteId = payload['remote_id'] as String?;
        if (remoteId == null) return false;
        await _supabase!.from(table).delete().eq('id', remoteId);
        return true;
      default:
        debugPrint('Sync: unknown operation "${item.operation}"');
        return false;
    }
  }

  /// Enqueue a change for later sync.
  Future<void> enqueue({
    required String table,
    required int rowId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final dao = SyncQueueDao(_db);
    await dao.enqueue(SyncQueueCompanion(
      syncTableName: Value(table),
      rowId: Value(rowId),
      operation: Value(operation),
      payload: Value(jsonEncode(payload)),
      createdAt: Value(DateTime.now()),
    ));

    // Attempt immediate sync (properly awaited)
    await syncAll();
  }
}
