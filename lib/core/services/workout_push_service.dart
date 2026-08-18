import 'dart:async';

import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Uploads finished workouts to Supabase — the path that closes the
/// "client never pushes workout data" blocker (SETUP-STATUS).
///
/// One `push_workout` RPC outbox item per finished session: the session
/// summary plus its performed exercises and completed sets, atomic
/// server-side (migration 019). Ids are client-generated uuids persisted in
/// the local rows' `remoteId`, which makes re-pushes idempotent AND doubles
/// as the "already enqueued" marker: [pushPending] simply scans for finished
/// sessions with no remoteId, so history from before this feature (or from
/// a signed-out stretch) backfills on the next sign-in with no stored flag.
///
/// Everything runs inside ONE local transaction with an atomic uuid claim
/// (`UPDATE … WHERE remote_id IS NULL`): concurrent invocations — the auth
/// listener fires the backfill on several back-to-back events — either win
/// the claim or reuse/skip, so a session can never be pushed twice under
/// different uuids, and a crash can never leave the marker set without its
/// queue row (they commit together).
class WorkoutPushService {
  WorkoutPushService(this._db, this._sync)
      : _sessionDao = SessionDao(_db),
        _profileDao = UserProfileDao(_db);

  final AppDatabase _db;
  final SyncService _sync;
  final SessionDao _sessionDao;
  final UserProfileDao _profileDao;

  static const _uuid = Uuid();

  /// Server-side bounds (migration 019 raises above these); the builder
  /// truncates instead so a pathological session degrades, never poisons
  /// the queue with a permanently-rejected item.
  static const maxExercisesPerPush = 50;
  static const maxSetsPerExercise = 100;

  /// Cap per scan so a huge pre-existing history can't flood one sync pass;
  /// the remainder goes on the next sign-in scan.
  static const backfillBatchLimit = 200;

  /// Enqueue the finished session [sessionLocalId] for upload. Skips
  /// unfinished sessions and devices with no synced profile (nothing to own
  /// the rows server-side — the sign-in backfill picks those up later).
  ///
  /// [onlyIfUnclaimed] is the backfill mode: when another invocation claimed
  /// the session between the scan and here, skip instead of enqueuing a
  /// duplicate item. Direct calls (session finish) always enqueue — a
  /// re-push with the same uuids is how server-side healing works.
  Future<void> enqueuePush(
    int sessionLocalId, {
    bool onlyIfUnclaimed = false,
  }) async {
    final profile = await _profileDao.getFirst();
    if (profile?.remoteId == null) return;

    var enqueued = false;
    await _db.transaction(() async {
      final session = await _sessionDao.getById(sessionLocalId);
      if (session == null || session.finishedAt == null) return;

      var claimedNow = false;
      var sessionUuid = session.remoteId;
      if (sessionUuid == null) {
        final candidate = _uuid.v4();
        final claimed = await (_db.update(_db.sessions)
              ..where((t) =>
                  t.localId.equals(sessionLocalId) & t.remoteId.isNull()))
            .write(SessionsCompanion(
          remoteId: Value(candidate),
          syncStatus: const Value('pending'),
        ));
        claimedNow = claimed == 1;
        sessionUuid = claimedNow
            ? candidate
            : (await _sessionDao.getById(sessionLocalId))?.remoteId;
      }
      if (sessionUuid == null) return;
      if (onlyIfUnclaimed && !claimedNow) return;

      final exercises =
          await _sessionDao.getSessionExercisesForSessions([sessionLocalId]);
      final sets = await _sessionDao
          .getSetsForSessionExercises([for (final e in exercises) e.localId]);
      final setsBySe = <int, List<WorkoutSet>>{};
      for (final s in sets) {
        if (s.isCompleted) {
          setsBySe.putIfAbsent(s.sessionExerciseId, () => []).add(s);
        }
      }

      final completedAt =
          (session.finishedAt ?? session.startedAt).toUtc().toIso8601String();
      final exercisePayloads = <Map<String, dynamic>>[];
      for (final ex in exercises) {
        final exSets = setsBySe[ex.localId] ?? const [];
        // Exercises the user never actually performed stay local-only.
        if (exSets.isEmpty) continue;
        if (exercisePayloads.length >= maxExercisesPerPush) break;

        final exUuid = ex.remoteId ?? await _claimChildUuid(
              claim: (uuid) => (_db.update(_db.sessionExercises)
                    ..where((t) =>
                        t.localId.equals(ex.localId) & t.remoteId.isNull()))
                  .write(SessionExercisesCompanion(remoteId: Value(uuid))),
              reread: () async => (await (_db.select(_db.sessionExercises)
                        ..where((t) => t.localId.equals(ex.localId)))
                      .getSingleOrNull())
                  ?.remoteId,
            );
        if (exUuid == null) continue;

        final setPayloads = <Map<String, dynamic>>[];
        for (final s in exSets.take(maxSetsPerExercise)) {
          final setUuid = s.remoteId ?? await _claimChildUuid(
                claim: (uuid) => (_db.update(_db.workoutSets)
                      ..where((t) =>
                          t.localId.equals(s.localId) & t.remoteId.isNull()))
                    .write(WorkoutSetsCompanion(remoteId: Value(uuid))),
                reread: () async => (await (_db.select(_db.workoutSets)
                          ..where((t) => t.localId.equals(s.localId)))
                        .getSingleOrNull())
                    ?.remoteId,
              );
          if (setUuid == null) continue;
          setPayloads.add({
            'id': setUuid,
            'set_index': s.setIndex,
            // Server column names differ from Drift's (001 schema).
            'weight_kg': s.weight,
            'reps': s.reps,
            'is_warmup': s.isWarmup,
            'is_dropset': s.isDropset,
            'rpe': s.rpe,
            'completed_at': completedAt,
          });
        }

        exercisePayloads.add({
          'id': exUuid,
          'exercise_id': ex.exerciseId,
          'order_index': ex.orderIndex,
          'sets': setPayloads,
        });
      }

      // Queue row commits WITH the uuid claims — a crash can't leave the
      // session marked pushed-but-never-queued. The sync kick happens after
      // commit (kicking inside the transaction zone would let the drain
      // race the commit).
      await _sync.enqueue(
        table: 'push_workout',
        rowId: sessionLocalId,
        operation: 'rpc',
        kickSync: false,
        payload: {
          'session': {
            'id': sessionUuid,
            'started_at': session.startedAt.toUtc().toIso8601String(),
            'finished_at': session.finishedAt?.toUtc().toIso8601String(),
            'duration_seconds': session.durationSeconds,
            'total_volume_kg': session.totalVolume,
            'notes': session.notes,
          },
          'exercises': exercisePayloads,
        },
      );
      enqueued = true;
    });
    if (enqueued) unawaited(_sync.syncAll());
  }

  /// Claim-or-reuse for child rows: write [claim]'s uuid where none exists,
  /// re-read on a lost claim (partial assignment from an earlier crash).
  Future<String?> _claimChildUuid({
    required Future<int> Function(String uuid) claim,
    required Future<String?> Function() reread,
  }) async {
    final candidate = _uuid.v4();
    if (await claim(candidate) == 1) return candidate;
    return reread();
  }

  /// Enqueue every finished session that was never pushed (remoteId null) —
  /// pre-feature history and sessions finished while signed out. Called on
  /// sign-in, before the sync drain. Idempotent AND race-free: the atomic
  /// claim inside [enqueuePush] makes overlapping scans (supabase-auth fires
  /// several events back-to-back) skip already-claimed sessions.
  Future<void> pushPending() async {
    final profile = await _profileDao.getFirst();
    if (profile?.remoteId == null) return;

    final rows = await (_db.select(_db.sessions)
          ..where((t) =>
              t.finishedAt.isNotNull() &
              t.remoteId.isNull() &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt)])
          ..limit(backfillBatchLimit))
        .get();
    for (final row in rows) {
      await enqueuePush(row.localId, onlyIfUnclaimed: true);
    }
  }
}
