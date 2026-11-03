import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// The account's routines in the cloud: read them all, push one.
abstract interface class ScheduleCloud {
  /// True when a signed-in session exists (pushes would run as anon
  /// otherwise and be rejected).
  bool get isSignedIn;

  /// Every non-deleted schedule of the signed-in user, each with
  /// `schedule_days` → `scheduled_exercises` nested.
  Future<List<Map<String, dynamic>>> fetchSchedules();

  /// One `push_schedule` call (migration 024).
  Future<void> pushSchedule(Map<String, dynamic> payload);
}

/// [ScheduleCloud] over the Data API. Reads rely on 001's own-row SELECT
/// policies and 018's grants; writes go through `push_schedule` (024).
class SupabaseScheduleCloud implements ScheduleCloud {
  const SupabaseScheduleCloud(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, name, is_active, '
      'schedule_days(day_index, label, is_rest_day, '
      'scheduled_exercises(exercise_id, order_index, target_sets, '
      'target_reps, target_duration_seconds, target_distance))';

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    final rows = await _client
        .from('schedules')
        .select(_columns)
        .isFilter('deleted_at', null)
        .order('created_at')
        .timeout(const Duration(seconds: 30));
    return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
  }

  @override
  Future<void> pushSchedule(Map<String, dynamic> payload) =>
      _client.rpc<void>('push_schedule', params: {'p': payload});
}

/// Backs up workout routines (schedules) to the account and brings them back
/// on a reinstall or a new phone. Before this, routines never left the
/// device: `push_workout` (019) carried finished sessions only.
///
/// How it works:
///  * **Reconcile on sign-in** ([reconcile]): fetch the account's routines and
///    insert the ones this device doesn't have (matched by `remoteId`). A
///    never-uploaded local routine with the same name as a restored one is a
///    duplicate — on a fresh install that's the bundled starter programs the
///    seeder just created — and is removed unless a logged session points
///    at it. Pushes are allowed only after a successful reconcile for the
///    signed-in account, so a fresh device can never upload its starter
///    programs over the account's real routines before seeing them.
///  * **Push on change** ([pushChanged]): each routine is serialized whole
///    (schedule + days + exercises) and hashed; the hash of the last
///    successful push lives in the schedule row's `syncStatus`
///    (`synced:<hash>`). Anything whose hash differs is pushed. No outbox
///    row is needed — an offline edit simply stays "different" until the next
///    push succeeds, which also covers every edit made before this feature.
///    A debounced watcher on the three schedule tables triggers it, so no
///    write site has to remember to call it.
///  * **Deletes** are hard deletes locally, so they go through the outbox
///    ([enqueueDelete]) before the row — and its uuid — disappears.
class ScheduleSyncService {
  ScheduleSyncService(this._db, this._cloud);

  final AppDatabase _db;
  final ScheduleCloud? _cloud;

  static const _uuid = Uuid();
  static const _syncedPrefix = 'synced:';

  /// The account a reconcile last succeeded for, this app session.
  String? _reconciledFor;
  Future<void>? _reconcileInFlight;
  Future<void>? _pushInFlight;
  bool _pushAgain = false;
  StreamSubscription<Set<TableUpdate>>? _watch;
  Timer? _debounce;

  /// Delay between the last schedule-table write and the push it triggers,
  /// so a builder screen's burst of writes becomes one push.
  @visibleForTesting
  static Duration debounce = const Duration(seconds: 3);

  /// Fetch the account's routines, restore the missing ones, then push local
  /// changes and start watching for more. Runs at most once per account per
  /// app session; later calls only push. Failures (offline) leave pushes
  /// disabled until a later sign-in event retries.
  Future<void> reconcile(String userId) {
    if (_reconciledFor == userId) return pushChanged();
    final running = _reconcileInFlight;
    if (running != null) return running;
    final run = _reconcile(userId).whenComplete(() => _reconcileInFlight = null);
    _reconcileInFlight = run;
    return run;
  }

  Future<void> _reconcile(String userId) async {
    final cloud = _cloud;
    if (cloud == null || !cloud.isSignedIn) return;
    final profile = await UserProfileDao(_db).getFirst();
    if (profile?.remoteId != userId) return;

    final List<Map<String, dynamic>> rows;
    try {
      rows = await cloud.fetchSchedules();
    } on Object catch (e) {
      debugPrint('Schedule sync: fetch failed, will retry later: $e');
      return;
    }
    await restore(rows);
    _reconciledFor = userId;
    _startWatching();
    await pushChanged();
  }

  /// Forget the reconciled account (sign-out / account switch): no pushes
  /// until the next account reconciles.
  void reset() {
    _reconciledFor = null;
    _debounce?.cancel();
    _debounce = null;
  }

  void dispose() {
    reset();
    _watch?.cancel();
    _watch = null;
  }

  void _startWatching() {
    _watch ??= _db
        .tableUpdates(TableUpdateQuery.onAllTables(
            [_db.schedules, _db.scheduleDays, _db.scheduledExercises]))
        .listen((_) {
      _debounce?.cancel();
      _debounce = Timer(debounce, () {
        _debounce = null;
        unawaited(pushChanged());
      });
    });
  }

  // ── restore ─────────────────────────────────────────────────────────

  /// Insert the server routines this device doesn't have. Returns how many
  /// were inserted. Public for tests.
  @visibleForTesting
  Future<int> restore(List<Map<String, dynamic>> rows) =>
      _db.transaction(() async {
        final local = await _db.select(_db.schedules).get();
        final known = {
          for (final s in local)
            if (s.remoteId != null) s.remoteId!,
        };
        final freshDevice = known.isEmpty;

        final restored = <({int localId, String name, bool active})>[];
        for (final row in rows) {
          final id = row['id'] as String?;
          final name = row['name'] as String?;
          if (id == null || name == null || !known.add(id)) continue;
          final now = DateTime.now();
          final scheduleId =
              await _db.into(_db.schedules).insert(SchedulesCompanion.insert(
                    name: name,
                    remoteId: Value(id),
                    isActive: const Value(false),
                    createdAt: Value(now),
                    updatedAt: Value(now),
                  ));
          final days = _maps(row['schedule_days']).toList()
            ..sort((a, b) =>
                (_int(a['day_index']) ?? 0).compareTo(_int(b['day_index']) ?? 0));
          for (final day in days) {
            final dayId = await _db
                .into(_db.scheduleDays)
                .insert(ScheduleDaysCompanion.insert(
                  scheduleId: scheduleId,
                  dayIndex: _int(day['day_index']) ?? 0,
                  label: Value(day['label'] as String?),
                  isRestDay: Value(day['is_rest_day'] == true),
                  syncStatus: const Value('synced'),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ));
            final exercises = _maps(day['scheduled_exercises']).toList()
              ..sort((a, b) => (_int(a['order_index']) ?? 0)
                  .compareTo(_int(b['order_index']) ?? 0));
            for (final ex in exercises) {
              final exerciseId = ex['exercise_id'] as String?;
              if (exerciseId == null) continue;
              await _db.into(_db.scheduledExercises).insert(
                    ScheduledExercisesCompanion.insert(
                      scheduleDayId: dayId,
                      exerciseId: exerciseId,
                      orderIndex: _int(ex['order_index']) ?? 0,
                      targetSets: Value(_int(ex['target_sets']) ?? 3),
                      targetReps: Value(_int(ex['target_reps']) ?? 10),
                      targetDurationSeconds:
                          Value(_int(ex['target_duration_seconds'])),
                      targetDistance: Value(_real(ex['target_distance'])),
                      syncStatus: const Value('synced'),
                      createdAt: Value(now),
                      updatedAt: Value(now),
                    ),
                  );
            }
          }
          restored.add((
            localId: scheduleId,
            name: name,
            active: row['is_active'] == true,
          ));
        }
        if (restored.isEmpty) return 0;

        // Never-uploaded local copies of a restored routine (the starter
        // programs a fresh install seeds) are duplicates.
        final restoredNames = {for (final r in restored) r.name.toLowerCase()};
        for (final s in local) {
          if (s.remoteId != null) continue;
          if (!restoredNames.contains(s.name.toLowerCase())) continue;
          if (await _referencedBySessions(s.localId)) continue;
          await _hardDelete(s.localId);
        }

        // On a device that had never synced routines, the account's active
        // routine wins; otherwise only fill the gap when none is active.
        final activeRestored =
            restored.where((r) => r.active).map((r) => r.localId).firstOrNull;
        if (activeRestored != null) {
          final anyActive = await (_db.select(_db.schedules)
                ..where((t) => t.isActive.equals(true))
                ..limit(1))
              .getSingleOrNull();
          if (freshDevice || anyActive == null) {
            await _db.update(_db.schedules).write(
                  const SchedulesCompanion(isActive: Value(false)),
                );
            await (_db.update(_db.schedules)
                  ..where((t) => t.localId.equals(activeRestored)))
                .write(const SchedulesCompanion(isActive: Value(true)));
          }
        }

        // Restored routines match the server: stamp their hash so they are
        // not pushed straight back.
        for (final r in restored) {
          final payload = await _payload(r.localId);
          if (payload == null) continue;
          await _stampSynced(r.localId, _hash(payload));
        }
        return restored.length;
      });

  Future<bool> _referencedBySessions(int scheduleLocalId) async {
    final dayIds = (await (_db.select(_db.scheduleDays)
              ..where((t) => t.scheduleId.equals(scheduleLocalId)))
            .get())
        .map((d) => d.localId)
        .toList();
    final ref = await (_db.select(_db.sessions)
          ..where((t) =>
              t.scheduleId.equals(scheduleLocalId) |
              (dayIds.isEmpty
                  ? const Constant(false)
                  : t.scheduleDayId.isIn(dayIds)))
          ..limit(1))
        .getSingleOrNull();
    return ref != null;
  }

  Future<void> _hardDelete(int scheduleLocalId) async {
    final dayIds = (await (_db.select(_db.scheduleDays)
              ..where((t) => t.scheduleId.equals(scheduleLocalId)))
            .get())
        .map((d) => d.localId)
        .toList();
    if (dayIds.isNotEmpty) {
      await (_db.delete(_db.scheduledExercises)
            ..where((t) => t.scheduleDayId.isIn(dayIds)))
          .go();
    }
    await (_db.delete(_db.scheduleDays)
          ..where((t) => t.scheduleId.equals(scheduleLocalId)))
        .go();
    await (_db.delete(_db.schedules)
          ..where((t) => t.localId.equals(scheduleLocalId)))
        .go();
  }

  // ── push ────────────────────────────────────────────────────────────

  /// Push every routine whose content changed since its last successful
  /// push. A no-op until [reconcile] succeeded for the signed-in account.
  /// Concurrent calls coalesce into one extra pass.
  Future<void> pushChanged() {
    final running = _pushInFlight;
    if (running != null) {
      _pushAgain = true;
      return running;
    }
    final run = _pushLoop().whenComplete(() => _pushInFlight = null);
    _pushInFlight = run;
    return run;
  }

  Future<void> _pushLoop() async {
    do {
      _pushAgain = false;
      await _pushOnce();
    } while (_pushAgain);
  }

  Future<void> _pushOnce() async {
    final cloud = _cloud;
    final account = _reconciledFor;
    if (cloud == null || account == null || !cloud.isSignedIn) return;
    final profile = await UserProfileDao(_db).getFirst();
    if (profile?.remoteId != account) return;

    final schedules = await _db.select(_db.schedules).get();
    for (final s in schedules) {
      if (s.deletedAt != null) continue;
      final remoteId = s.remoteId ?? await _claimRemoteId(s.localId);
      if (remoteId == null) continue;
      final payload = await _payload(s.localId);
      if (payload == null) continue;
      final hash = _hash(payload);
      if (s.syncStatus == '$_syncedPrefix$hash') continue;
      try {
        await cloud.pushSchedule(payload);
      } on PostgrestException catch (e) {
        if (SyncService.isPermanentPgCode(e.code)) {
          // The server will reject this version forever (bounds, ownership):
          // record it as handled so it isn't retried until it changes.
          CrashReporter.recordError(
            e,
            reason: 'Schedule push permanently rejected (${e.code})',
          );
          await _stampSynced(s.localId, hash);
          continue;
        }
        debugPrint('Schedule sync: push failed, will retry: $e');
        return;
      } on Object catch (e) {
        debugPrint('Schedule sync: push failed, will retry: $e');
        return; // offline / transient: the next trigger retries
      }
      await _stampSynced(s.localId, hash);
    }
  }

  /// Atomic claim, as in `WorkoutPushService`: two overlapping passes can't
  /// give one routine two uuids.
  Future<String?> _claimRemoteId(int localId) async {
    final candidate = _uuid.v4();
    final claimed = await (_db.update(_db.schedules)
          ..where((t) => t.localId.equals(localId) & t.remoteId.isNull()))
        .write(SchedulesCompanion(remoteId: Value(candidate)));
    if (claimed == 1) return candidate;
    return (await (_db.select(_db.schedules)
              ..where((t) => t.localId.equals(localId)))
            .getSingleOrNull())
        ?.remoteId;
  }

  Future<void> _stampSynced(int localId, String hash) =>
      (_db.update(_db.schedules)..where((t) => t.localId.equals(localId)))
          .write(SchedulesCompanion(syncStatus: Value('$_syncedPrefix$hash')));

  /// The `push_schedule` payload for one routine, or null if it vanished.
  Future<Map<String, dynamic>?> _payload(int localId) async {
    final s = await (_db.select(_db.schedules)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    if (s == null || s.remoteId == null) return null;
    final days = await (_db.select(_db.scheduleDays)
          ..where((t) => t.scheduleId.equals(localId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.dayIndex),
            (t) => OrderingTerm(expression: t.localId),
          ]))
        .get();
    final dayPayloads = <Map<String, dynamic>>[];
    for (final d in days) {
      final exercises = await (_db.select(_db.scheduledExercises)
            ..where((t) => t.scheduleDayId.equals(d.localId) & t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.orderIndex),
              (t) => OrderingTerm(expression: t.localId),
            ]))
          .get();
      dayPayloads.add({
        'day_index': d.dayIndex,
        'label': d.label,
        'is_rest_day': d.isRestDay,
        'exercises': [
          for (final e in exercises)
            {
              'exercise_id': e.exerciseId,
              'order_index': e.orderIndex,
              'target_sets': e.targetSets,
              'target_reps': e.targetReps,
              'target_duration_seconds': e.targetDurationSeconds,
              'target_distance': e.targetDistance,
            },
        ],
      });
    }
    return {
      'id': s.remoteId,
      'name': s.name,
      'is_active': s.isActive,
      'days': dayPayloads,
    };
  }

  static String _hash(Map<String, dynamic> payload) =>
      sha1.convert(utf8.encode(jsonEncode(payload))).toString();

  // ── delete ──────────────────────────────────────────────────────────

  /// Queue the server-side delete of routine [localId]. Call BEFORE the
  /// local hard delete — it reads the uuid the delete destroys. A routine
  /// that was never uploaded needs nothing.
  static Future<void> enqueueDelete(
    AppDatabase db,
    SyncService sync,
    int localId,
  ) async {
    final s = await (db.select(db.schedules)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    final remoteId = s?.remoteId;
    if (remoteId == null) return;
    await sync.enqueue(
      table: 'push_schedule',
      rowId: localId,
      operation: 'rpc',
      payload: {'id': remoteId, 'deleted': true},
    );
  }

  static Iterable<Map<String, dynamic>> _maps(Object? v) => v is List
      ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)]
      : const [];

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static double? _real(Object? v) => v is num ? v.toDouble() : null;
}
