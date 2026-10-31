import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the restore reads a user's workout history from. One call = one page
/// of finished, non-deleted sessions, each with its exercises and sets nested
/// (`session_exercises` → `sets`), newest first.
abstract interface class WorkoutHistorySource {
  Future<List<Map<String, dynamic>>> fetchSessionPage({
    required int offset,
    required int limit,
  });
}

/// Reads history straight from the Data API. No migration is needed: 001's
/// own-row SELECT policies and 018's `GRANT SELECT … TO authenticated` already
/// cover `sessions`, `session_exercises` and `sets`; `anon` has no grant, so a
/// signed-out client gets nothing.
class SupabaseWorkoutHistorySource implements WorkoutHistorySource {
  const SupabaseWorkoutHistorySource(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, started_at, finished_at, duration_seconds, '
      'total_volume_kg, notes, '
      'session_exercises(id, exercise_id, order_index, deleted_at, '
      'sets(id, set_index, weight_kg, reps, is_warmup, is_dropset, rpe, '
      'completed_at, deleted_at))';

  @override
  Future<List<Map<String, dynamic>>> fetchSessionPage({
    required int offset,
    required int limit,
  }) async {
    final rows = await _client
        .from('sessions')
        .select(_columns)
        .isFilter('deleted_at', null)
        .not('finished_at', 'is', null)
        .order('started_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
  }
}

/// Pull-on-sign-in restore of workout history — the other half of
/// `WorkoutPushService`. After a delete + reinstall (or a new phone) the local
/// Drift DB is empty while the account's history sits in Supabase; without
/// this the Workout/Progress/Streak screens stay blank.
///
/// Rules:
///  * Runs only when the device has **no local sessions at all**, so it can
///    never interleave with, duplicate or overwrite local work.
///  * Fetches every page into memory first and writes in ONE transaction:
///    either the whole history lands or nothing does. A failed fetch (offline,
///    timeout, RLS) leaves the DB empty, so the next sign-in retries — the
///    empty-DB check is the only "done" marker needed. (A keychain flag would
///    be wrong: iOS keeps the Keychain across a reinstall, the DB it
///    describes is gone.)
///  * Idempotent by `remoteId`: a server session that already exists locally
///    (or appears twice) is skipped, so an overlapping run is harmless.
///  * Restored rows carry the server uuids, `syncStatus = 'synced'`, and the
///    sign-in backfill ignores them (it only scans `remote_id IS NULL`).
///  * Unfinished and soft-deleted sessions/exercises/sets are not restored.
class WorkoutRestoreService {
  WorkoutRestoreService(this._db, this._source);

  final AppDatabase _db;
  final WorkoutHistorySource? _source;
  Future<int>? _inFlight;

  /// Sessions per request. Embedded children make each row heavier than a
  /// plain table row, so keep pages modest.
  static const pageSize = 100;

  /// Safety ceiling (10,000 sessions) so a pathological account can't loop
  /// forever; anything beyond is simply not restored.
  static const maxPages = 100;

  static const _pageTimeout = Duration(seconds: 30);

  /// Restores the history of [userId] if this device has none. Returns the
  /// number of sessions written (0 when skipped, offline or empty).
  Future<int> restoreIfEmpty(String userId) {
    final running = _inFlight;
    if (running != null) return running;
    final run = _restore(userId).whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<int> _restore(String userId) async {
    final source = _source;
    if (source == null) return 0;

    // Only ever restore into the signed-in account's own profile; a switch
    // that hasn't wiped/claimed yet must not receive someone else's history.
    final profile = await UserProfileDao(_db).getFirst();
    if (profile?.remoteId != userId) return 0;
    if (await _hasLocalSessions()) return 0;

    final rows = <Map<String, dynamic>>[];
    try {
      for (var page = 0; page < maxPages; page++) {
        final batch = await source
            .fetchSessionPage(offset: page * pageSize, limit: pageSize)
            .timeout(_pageTimeout);
        rows.addAll(batch);
        if (batch.length < pageSize) break;
      }
    } on Exception catch (e) {
      // Offline / transient: write nothing so the next sign-in retries.
      debugPrint('Workout restore: fetch failed, will retry later: $e');
      return 0;
    }
    if (rows.isEmpty) return 0;
    return _insert(rows);
  }

  Future<bool> _hasLocalSessions() async =>
      (await (_db.select(_db.sessions)..limit(1)).get()).isNotEmpty;

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static double? _real(Object? v) => v is num ? v.toDouble() : null;

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static Iterable<Map<String, dynamic>> _maps(Object? v) => v is List
      ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)]
      : const [];

  Future<int> _insert(List<Map<String, dynamic>> rows) =>
      _db.transaction(() async {
        final known = <String>{
          for (final s in await (_db.select(_db.sessions)
                    ..where((t) => t.remoteId.isNotNull()))
                  .get())
            s.remoteId!,
        };
        var restored = 0;
        final now = DateTime.now();

        for (final row in rows) {
          final id = row['id'] as String?;
          final started = _time(row['started_at']);
          final finished = _time(row['finished_at']);
          // Unfinished rows would resurface as a live "resume workout".
          if (id == null || started == null || finished == null) continue;
          if (!known.add(id)) continue;

          final localSession =
              await _db.into(_db.sessions).insert(SessionsCompanion.insert(
                    startedAt: started,
                    remoteId: Value(id),
                    syncStatus: const Value('synced'),
                    createdAt: Value(now),
                    updatedAt: Value(now),
                    finishedAt: Value(finished),
                    durationSeconds: Value(_int(row['duration_seconds'])),
                    totalVolume: Value(_real(row['total_volume_kg'])),
                    notes: Value(row['notes'] as String?),
                  ));

          final exercises = [
            for (final e in _maps(row['session_exercises']))
              if (e['deleted_at'] == null) e,
          ]..sort((a, b) => (_int(a['order_index']) ?? 0)
              .compareTo(_int(b['order_index']) ?? 0));

          for (final ex in exercises) {
            final exId = ex['id'] as String?;
            final exerciseId = ex['exercise_id'] as String?;
            if (exId == null || exerciseId == null) continue;
            final localExercise = await _db
                .into(_db.sessionExercises)
                .insert(SessionExercisesCompanion.insert(
                  sessionId: localSession,
                  exerciseId: exerciseId,
                  orderIndex: _int(ex['order_index']) ?? 0,
                  remoteId: Value(exId),
                  syncStatus: const Value('synced'),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ));

            final sets = <WorkoutSetsCompanion>[];
            for (final s in _maps(ex['sets'])) {
              if (s['deleted_at'] != null) continue;
              final setId = s['id'] as String?;
              if (setId == null) continue;
              sets.add(WorkoutSetsCompanion.insert(
                sessionExerciseId: localExercise,
                setIndex: _int(s['set_index']) ?? 0,
                remoteId: Value(setId),
                syncStatus: const Value('synced'),
                createdAt: Value(now),
                updatedAt: Value(now),
                weight: Value(_real(s['weight_kg'])),
                reps: Value(_int(s['reps'])),
                isWarmup: Value(s['is_warmup'] == true),
                isDropset: Value(s['is_dropset'] == true),
                // Only completed sets are ever uploaded (the push builder
                // filters), so every server set was a done set.
                isCompleted: const Value(true),
                rpe: Value(_real(s['rpe'])?.round()),
              ));
            }
            sets.sort((a, b) => a.setIndex.value.compareTo(b.setIndex.value));
            if (sets.isNotEmpty) {
              await _db.batch((b) => b.insertAll(_db.workoutSets, sets));
            }
          }
          restored++;
        }
        return restored;
      });
}
