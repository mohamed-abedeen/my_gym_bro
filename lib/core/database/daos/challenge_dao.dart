import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'challenge_dao.g.dart';

/// Data access for the local challenge cache — the challenge list snapshot
/// plus the current user's participation rows. This is the offline source of
/// truth for what the Bros tab's Challenges view renders.
@DriftAccessor(tables: [Challenges, ChallengeParticipants])
class ChallengeDao extends DatabaseAccessor<AppDatabase>
    with _$ChallengeDaoMixin {
  ChallengeDao(super.db);

  // ── challenges ────────────────────────────────────────────────────────────

  /// Live stream of every non-deleted, non-hidden challenge, newest window
  /// first. Hidden rows are filtered here too in case a moderation flip lands
  /// in a snapshot before the row is purged.
  Stream<List<Challenge>> watchAll() {
    final q = select(challenges)
      ..where((t) => t.deletedAt.isNull() & t.status.equals('hidden').not())
      ..orderBy([
        (t) => OrderingTerm(expression: t.startsAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  Future<Challenge?> findByRemoteId(String remoteId) {
    return (select(challenges)
          ..where((t) => t.remoteId.equals(remoteId) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Insert a locally-created community challenge (or revive/update the row
  /// carrying the same remote id after a snapshot race). The conflict target
  /// must be the `remoteId` unique key explicitly — the default
  /// `insertOnConflictUpdate` only targets the primary key (localId), which
  /// the companion never carries, so it would throw instead of upserting.
  Future<int> upsertChallenge(ChallengesCompanion row) {
    return into(challenges).insert(
      row,
      onConflict: DoUpdate((_) => row, target: [challenges.remoteId]),
    );
  }

  /// Hard-delete a challenge row locally (creator takedown). The remote
  /// delete is queued separately and carries the remote id in its payload.
  Future<void> deleteByRemoteId(String remoteId) async {
    await (delete(challengeParticipants)
          ..where((t) => t.challengeRemoteId.equals(remoteId)))
        .go();
    await (delete(challenges)..where((t) => t.remoteId.equals(remoteId))).go();
  }

  /// Replace the challenge list from a server snapshot.
  ///
  /// Callers run this only after `syncAll()` has genuinely drained the
  /// outbox, so a server row IS the truth for any local row sharing its
  /// remote id — the upsert overwrites pushed-but-still-'pending' local rows
  /// (that's how server-side status flips like 'ended'/'hidden' land on the
  /// creating device). Local rows the server doesn't know are kept briefly
  /// (fresh, likely queued behind a transient failure) but purged once stale:
  /// after a full drain, a >24h-old pending row means its push was
  /// permanently rejected — a phantom that would otherwise render forever.
  Future<void> replaceChallengesFromServer(
    List<ChallengesCompanion> serverRows,
  ) async {
    final serverIds = {
      for (final row in serverRows)
        if (row.remoteId.present && row.remoteId.value != null)
          row.remoteId.value!,
    };
    final staleCutoff = DateTime.now().subtract(const Duration(hours: 24));
    await transaction(() async {
      await (delete(challenges)..where((t) => t.syncStatus.equals('synced')))
          .go();
      for (final row in serverRows) {
        await into(challenges).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [challenges.remoteId]),
        );
      }
      await (delete(challenges)
            ..where((t) =>
                t.syncStatus.equals('pending') &
                t.remoteId.isNotIn(serverIds.toList()) &
                t.updatedAt.isSmallerThanValue(staleCutoff)))
          .go();
    });
  }

  // ── participation ─────────────────────────────────────────────────────────

  /// Live stream of [userId]'s non-deleted participation rows.
  Stream<List<ChallengeParticipant>> watchParticipation(String userId) {
    final q = select(challengeParticipants)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull());
    return q.watch();
  }

  Future<ChallengeParticipant?> findParticipation(
    String challengeRemoteId,
    String userId,
  ) {
    return (select(challengeParticipants)
          ..where((t) =>
              t.challengeRemoteId.equals(challengeRemoteId) &
              t.userId.equals(userId) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Insert (or revive) a participation row. Returns the row's local id.
  /// Conflict target is the (challenge, user) unique key — see
  /// [upsertChallenge] for why the default PK target would throw instead.
  Future<int> upsertParticipation(ChallengeParticipantsCompanion row) {
    return into(challengeParticipants).insert(
      row,
      onConflict: DoUpdate(
        (_) => row,
        target: [
          challengeParticipants.challengeRemoteId,
          challengeParticipants.userId,
        ],
      ),
    );
  }

  /// Update progress/completion in place and mark the row pending for sync.
  Future<void> updateParticipation(
    int localId, {
    required double progress,
    DateTime? completedAt,
  }) {
    return (update(challengeParticipants)
          ..where((t) => t.localId.equals(localId)))
        .write(
      ChallengeParticipantsCompanion(
        progress: Value(progress),
        completedAt: Value(completedAt),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard-delete a participation row locally (leave challenge). The remote
  /// delete is queued separately; the hard delete frees the unique
  /// (challenge, user) key immediately so the user can re-join.
  Future<int> deleteParticipation(int localId) {
    return (delete(challengeParticipants)
          ..where((t) => t.localId.equals(localId)))
        .go();
  }

  /// Replace [userId]'s participation rows from a server snapshot. Same
  /// policy as [replaceChallengesFromServer]: after a real drain the server
  /// row wins (that's how the award trigger's `points_awarded` and corrected
  /// `completed_at` land on the device that joined), and stale pending rows
  /// the server rejected are purged.
  Future<void> replaceParticipationFromServer(
    String userId,
    List<ChallengeParticipantsCompanion> serverRows,
  ) async {
    final serverIds = {
      for (final row in serverRows)
        if (row.remoteId.present && row.remoteId.value != null)
          row.remoteId.value!,
    };
    final staleCutoff = DateTime.now().subtract(const Duration(hours: 24));
    await transaction(() async {
      await (delete(challengeParticipants)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('synced')))
          .go();
      for (final row in serverRows) {
        await into(challengeParticipants).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [
              challengeParticipants.challengeRemoteId,
              challengeParticipants.userId,
            ],
          ),
        );
      }
      await (delete(challengeParticipants)
            ..where((t) =>
                t.userId.equals(userId) &
                t.syncStatus.equals('pending') &
                t.remoteId.isNotIn(serverIds.toList()) &
                t.updatedAt.isSmallerThanValue(staleCutoff)))
          .go();
    });
  }

  // ── local progress aggregates ─────────────────────────────────────────────
  // Challenge progress is computed from the device's own workout data
  // (offline source of truth) and synced up; the server award trigger
  // validates the resulting completion. Windows are half-open [start, end).

  /// Total completed working-set volume (kg × reps) in the window.
  Future<double> volumeInWindow(DateTime start, DateTime end) async {
    final row = await customSelect(
      'SELECT CAST(COALESCE(SUM(ws.weight * ws.reps), 0) AS REAL) AS vol '
      'FROM workout_sets ws '
      'JOIN session_exercises se ON se.local_id = ws.session_exercise_id '
      'JOIN sessions s ON s.local_id = se.session_id '
      'WHERE ws.is_completed = 1 AND ws.is_warmup = 0 '
      'AND ws.deleted_at IS NULL AND se.deleted_at IS NULL '
      'AND ws.weight IS NOT NULL AND ws.reps IS NOT NULL '
      'AND s.deleted_at IS NULL '
      'AND s.started_at >= ? AND s.started_at < ?',
      variables: [Variable(start), Variable(end)],
      readsFrom: {
        db.workoutSets,
        db.sessionExercises,
        db.sessions,
      },
    ).getSingle();
    return row.read<double>('vol');
  }

  /// Finished sessions in the window.
  Future<int> sessionsInWindow(DateTime start, DateTime end) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM sessions '
      'WHERE deleted_at IS NULL AND finished_at IS NOT NULL '
      'AND finished_at >= ? AND finished_at < ?',
      variables: [Variable(start), Variable(end)],
      readsFrom: {db.sessions},
    ).getSingle();
    return row.read<int>('n');
  }

  /// Completed working sets in the window.
  Future<int> setsInWindow(DateTime start, DateTime end) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n '
      'FROM workout_sets ws '
      'JOIN session_exercises se ON se.local_id = ws.session_exercise_id '
      'JOIN sessions s ON s.local_id = se.session_id '
      'WHERE ws.is_completed = 1 AND ws.is_warmup = 0 '
      'AND ws.deleted_at IS NULL AND se.deleted_at IS NULL '
      'AND s.deleted_at IS NULL '
      'AND s.started_at >= ? AND s.started_at < ?',
      variables: [Variable(start), Variable(end)],
      readsFrom: {
        db.workoutSets,
        db.sessionExercises,
        db.sessions,
      },
    ).getSingle();
    return row.read<int>('n');
  }

  /// Distinct local-time training days with a finished session in the window
  /// (the 'streak' goal type's progress measure).
  Future<int> trainingDaysInWindow(DateTime start, DateTime end) async {
    final row = await customSelect(
      "SELECT COUNT(DISTINCT date(started_at, 'unixepoch', 'localtime')) AS n "
      'FROM sessions '
      'WHERE deleted_at IS NULL AND finished_at IS NOT NULL '
      'AND started_at >= ? AND started_at < ?',
      variables: [Variable(start), Variable(end)],
      readsFrom: {db.sessions},
    ).getSingle();
    return row.read<int>('n');
  }
}
