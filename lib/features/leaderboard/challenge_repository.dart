import 'package:drift/drift.dart' show Value;

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/challenge_dao.dart';
import 'package:my_gym_bro/core/security/input_sanitiser.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Outcome of joining a challenge.
enum JoinChallengeResult { joined, alreadyJoined, unavailable, notSignedIn }

/// Outcome of creating a community challenge.
enum CreateChallengeResult { created, invalid, notSignedIn }

/// Challenge goal types (PRD §5.9 / 03-DATABASE.md §3.2). 'custom' progress
/// is self-reported (mark-as-done); the rest are computed from local workout
/// data. Wire values match the server CHECK constraint.
const kChallengeGoalTypes = ['volume', 'sessions', 'sets', 'streak', 'custom'];

/// Community challenges cap (mirrors the RLS WITH CHECK in migration 014 —
/// points feed the leaderboard composite, so user-created challenges can't
/// mint unbounded points).
const kCommunityChallengeMaxPoints = 50;
const kCommunityChallengeMaxDays = 31;

/// Coordinates the local challenge cache with Supabase (Phase 4 — PRD §5.9,
/// 04-BACKEND.md §3.2/§3.5).
///
/// All user actions are **offline-first**: join / leave / create / report /
/// progress updates write the local cache and enqueue a sync op; they never
/// block on the network. Completion detection is local (progress computed
/// from the device's own sessions/sets), but the server's award trigger is
/// the source of truth for points — [refreshFromServer] reconciles.
class ChallengeRepository {
  ChallengeRepository({
    required ChallengeDao challengeDao,
    required SyncService syncService,
    required SupabaseClient? supabase,
  })  : _dao = challengeDao,
        _sync = syncService,
        _supabase = supabase;

  final ChallengeDao _dao;
  final SyncService _sync;
  final SupabaseClient? _supabase;

  static const _uuid = Uuid();

  /// How far back ended challenges stay in the local snapshot (history view).
  static const _historyWindow = Duration(days: 30);

  /// Challenges reported this session (see [report]).
  final _reportedChallengeIds = <String>{};

  /// The signed-in user's id, or null when signed-out / Supabase-less.
  String? get currentUserId => _supabase?.auth.currentUser?.id;

  /// Live stream of visible challenges (newest window first).
  Stream<List<Challenge>> watchChallenges() => _dao.watchAll();

  /// Live stream of the current user's participation rows.
  Stream<List<ChallengeParticipant>> watchMyParticipation() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);
    return _dao.watchParticipation(uid);
  }

  /// Join [challenge]: optimistic local write + queued sync insert. The
  /// participation row's Supabase `id` is generated here and stored as
  /// `remoteId` so progress updates and leaves can target it.
  Future<JoinChallengeResult> join(Challenge challenge) async {
    final uid = currentUserId;
    if (uid == null) return JoinChallengeResult.notSignedIn;
    final challengeId = challenge.remoteId;
    if (challengeId == null ||
        challenge.status != 'active' ||
        DateTime.now().isAfter(challenge.endsAt)) {
      return JoinChallengeResult.unavailable;
    }
    final existing = await _dao.findParticipation(challengeId, uid);
    if (existing != null) return JoinChallengeResult.alreadyJoined;

    final now = DateTime.now();
    final remoteId = _uuid.v4();
    // Progress starts at what the window already contains — deterministic
    // and matches how recompute will measure it from here on.
    final progress = await _computeProgress(challenge);
    final completedAt =
        progress >= challenge.goalValue && challenge.goalType != 'custom'
            ? now
            : null;
    await _dao.upsertParticipation(
      ChallengeParticipantsCompanion.insert(
        challengeRemoteId: challengeId,
        userId: uid,
        remoteId: Value(remoteId),
        progress: Value(progress),
        joinedAt: Value(now),
        completedAt: Value(completedAt),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _sync.enqueue(
      table: 'challenge_participants',
      rowId: 0, // carries its id in the payload; rowId is unused
      operation: 'insert',
      payload: {
        'id': remoteId,
        'challenge_id': challengeId,
        'user_id': uid,
        'progress': progress,
        'joined_at': now.toUtc().toIso8601String(),
        if (completedAt != null)
          'completed_at': completedAt.toUtc().toIso8601String(),
        // points_awarded is server-computed by the award trigger — never sent.
      },
    );
    return JoinChallengeResult.joined;
  }

  /// Leave a challenge: local hard delete + queued remote delete (frees the
  /// unique (challenge, user) key so the user can re-join later).
  Future<void> leave(ChallengeParticipant row) async {
    final uid = currentUserId;
    if (uid == null || row.userId != uid) return;
    await _dao.deleteParticipation(row.localId);
    final remoteId = row.remoteId;
    if (remoteId != null) {
      await _sync.enqueue(
        table: 'challenge_participants',
        rowId: row.localId,
        operation: 'delete',
        payload: {'remote_id': remoteId},
      );
    }
  }

  /// Create a community challenge: optimistic local write + queued sync
  /// insert. Lands 'active' (migration 014's launch moderation policy —
  /// report-threshold takedown, not pre-review).
  Future<CreateChallengeResult> create({
    required String title,
    required String goalType,
    required double goalValue,
    required int points,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
  }) async {
    final uid = currentUserId;
    if (uid == null) return CreateChallengeResult.notSignedIn;

    final cleanTitle = InputSanitiser.sanitise(title);
    final cleanDescription =
        description == null ? null : InputSanitiser.sanitise(description);
    // Must be at least as strict as the RLS WITH CHECK in migration 014 — a
    // locally-accepted row the server rejects becomes a phantom that never
    // syncs. The 12h back-date margin stays inside RLS's now()-1d bound even
    // when the queued insert syncs hours later.
    final now = DateTime.now();
    if (cleanTitle.isEmpty ||
        cleanTitle.length > 80 ||
        (cleanDescription != null && cleanDescription.length > 500) ||
        !kChallengeGoalTypes.contains(goalType) ||
        goalValue < 1 ||
        points < 0 ||
        points > kCommunityChallengeMaxPoints ||
        !endsAt.isAfter(startsAt) ||
        endsAt.isAfter(
            startsAt.add(const Duration(days: kCommunityChallengeMaxDays))) ||
        startsAt.isBefore(now.subtract(const Duration(hours: 12))) ||
        endsAt.isBefore(now)) {
      return CreateChallengeResult.invalid;
    }

    final remoteId = _uuid.v4();
    await _dao.upsertChallenge(
      ChallengesCompanion.insert(
        source: 'community',
        title: cleanTitle,
        goalType: goalType,
        goalValue: goalValue,
        startsAt: startsAt,
        endsAt: endsAt,
        remoteId: Value(remoteId),
        creatorId: Value(uid),
        description: Value(cleanDescription),
        points: Value(points),
        status: const Value('active'),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _sync.enqueue(
      table: 'challenges',
      rowId: 0,
      operation: 'insert',
      payload: {
        'id': remoteId,
        'source': 'community',
        'creator_id': uid,
        'title': cleanTitle,
        'description': cleanDescription,
        'goal_type': goalType,
        'goal_value': goalValue,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'points': points,
        'status': 'active',
      },
    );
    return CreateChallengeResult.created;
  }

  /// Creator takedown of their own community challenge: local hard delete +
  /// queued remote delete (participants cascade server-side).
  Future<void> deleteOwn(Challenge challenge) async {
    final uid = currentUserId;
    if (uid == null ||
        challenge.creatorId != uid ||
        challenge.source != 'community') {
      return;
    }
    final remoteId = challenge.remoteId;
    if (remoteId == null) return;
    await _dao.deleteByRemoteId(remoteId);
    await _sync.enqueue(
      table: 'challenges',
      rowId: challenge.localId,
      operation: 'delete',
      payload: {'remote_id': remoteId},
    );
  }

  /// Report a community challenge (store safety requirement). Insert-only
  /// server table with no local cache — rides the outbox; ≥3 distinct
  /// reporters auto-hide the challenge server-side (migration 014).
  ///
  /// Session-scoped dedupe: the server's UNIQUE (challenge, reporter) makes a
  /// second report a permanently-rejected op, so don't queue one. (A repeat
  /// across app restarts still queues once more; the sync service drops the
  /// rejected duplicate.)
  Future<void> report(Challenge challenge, String reason) async {
    final uid = currentUserId;
    if (uid == null || challenge.source != 'community') return;
    final remoteId = challenge.remoteId;
    if (remoteId == null || _reportedChallengeIds.contains(remoteId)) return;
    final clean = InputSanitiser.sanitise(reason);
    if (clean.isEmpty) return;
    _reportedChallengeIds.add(remoteId);
    await _sync.enqueue(
      table: 'challenge_reports',
      rowId: 0,
      operation: 'insert',
      payload: {
        'id': _uuid.v4(),
        'challenge_id': remoteId,
        'reporter_id': uid,
        'reason': clean,
      },
    );
  }

  /// Self-report completion of a 'custom' goal challenge (the only goal type
  /// the device can't measure).
  Future<void> markCustomComplete(
    Challenge challenge,
    ChallengeParticipant row,
  ) async {
    final uid = currentUserId;
    if (uid == null || row.userId != uid) return;
    if (challenge.goalType != 'custom' || row.completedAt != null) return;
    final now = DateTime.now();
    if (now.isBefore(challenge.startsAt) || now.isAfter(challenge.endsAt)) {
      return;
    }
    await _dao.updateParticipation(
      row.localId,
      progress: challenge.goalValue,
      completedAt: now,
    );
    await _enqueueProgressUpdate(row, challenge.goalValue, now);
  }

  /// Recompute progress for every joined, unfinished challenge from local
  /// workout data; sets completion when the goal is met inside the window.
  /// Called on tab open and after a session finishes — cheap, local-only,
  /// plus one queued sync op per row that actually changed.
  Future<void> recomputeProgress() async {
    final uid = currentUserId;
    if (uid == null) return;
    final rows = await _dao.watchParticipation(uid).first;
    final now = DateTime.now();
    for (final row in rows) {
      if (row.completedAt != null) continue;
      final challenge = await _dao.findByRemoteId(row.challengeRemoteId);
      if (challenge == null ||
          challenge.goalType == 'custom' ||
          now.isBefore(challenge.startsAt)) {
        continue;
      }
      final progress = await _computeProgress(challenge);
      // Completion must be observed inside the window — a goal discovered
      // after ends_at can't be honestly timestamped, and the server award
      // trigger would reject it anyway.
      final completedAt = progress >= challenge.goalValue &&
              !now.isAfter(challenge.endsAt)
          ? now
          : null;
      if (progress == row.progress && completedAt == null) continue;
      await _dao.updateParticipation(
        row.localId,
        progress: progress,
        completedAt: completedAt,
      );
      await _enqueueProgressUpdate(row, progress, completedAt);
    }
  }

  /// Push anything queued, then replace the local caches from the server.
  /// No-op offline — the local cache stays authoritative.
  Future<void> refreshFromServer() async {
    final uid = currentUserId;
    final sb = _supabase;
    if (uid == null || sb == null) return;
    // Drain the outbox first so a queued join/progress update isn't
    // resurrected or clobbered by the snapshot we're about to pull.
    await _sync.syncAll();
    try {
      final cutoff = DateTime.now().toUtc().subtract(_historyWindow);
      final challengeRows = await sb
          .from('challenges')
          .select()
          .or('ends_at.gte.${cutoff.toIso8601String()},creator_id.eq.$uid');
      await _dao.replaceChallengesFromServer([
        for (final r in challengeRows as List)
          _challengeFromRemote(r as Map<String, dynamic>),
      ]);
      final participationRows = await sb
          .from('challenge_participants')
          .select()
          .eq('user_id', uid);
      await _dao.replaceParticipationFromServer(uid, [
        for (final r in participationRows as List)
          _participationFromRemote(r as Map<String, dynamic>),
      ]);
    } on Exception {
      // Offline / transient — keep the cache as-is.
    }
  }

  Future<double> _computeProgress(Challenge challenge) async {
    final start = challenge.startsAt;
    final end = challenge.endsAt;
    switch (challenge.goalType) {
      case 'volume':
        return _dao.volumeInWindow(start, end);
      case 'sessions':
        return (await _dao.sessionsInWindow(start, end)).toDouble();
      case 'sets':
        return (await _dao.setsInWindow(start, end)).toDouble();
      case 'streak':
        return (await _dao.trainingDaysInWindow(start, end)).toDouble();
      default: // 'custom' — self-reported via markCustomComplete
        return 0;
    }
  }

  Future<void> _enqueueProgressUpdate(
    ChallengeParticipant row,
    double progress,
    DateTime? completedAt,
  ) async {
    final remoteId = row.remoteId;
    if (remoteId == null) return;
    await _sync.enqueue(
      table: 'challenge_participants',
      rowId: row.localId,
      operation: 'update',
      payload: {
        'remote_id': remoteId,
        'progress': progress,
        if (completedAt != null)
          'completed_at': completedAt.toUtc().toIso8601String(),
      },
    );
  }

  ChallengesCompanion _challengeFromRemote(Map<String, dynamic> r) {
    return ChallengesCompanion.insert(
      source: r['source'] as String,
      title: r['title'] as String,
      goalType: r['goal_type'] as String,
      goalValue: (r['goal_value'] as num).toDouble(),
      startsAt: _parseTimestamp(r['starts_at'])!,
      endsAt: _parseTimestamp(r['ends_at'])!,
      remoteId: Value(r['id'] as String),
      creatorId: Value(r['creator_id'] as String?),
      templateId: Value(r['template_id'] as String?),
      description: Value(r['description'] as String?),
      points: Value((r['points'] as num?)?.toInt() ?? 0),
      status: Value(r['status'] as String),
      createdAt: Value(_parseTimestamp(r['created_at'])),
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value('synced'),
    );
  }

  ChallengeParticipantsCompanion _participationFromRemote(
    Map<String, dynamic> r,
  ) {
    return ChallengeParticipantsCompanion.insert(
      challengeRemoteId: r['challenge_id'] as String,
      userId: r['user_id'] as String,
      remoteId: Value(r['id'] as String),
      progress: Value((r['progress'] as num?)?.toDouble() ?? 0),
      joinedAt: Value(_parseTimestamp(r['joined_at'])),
      completedAt: Value(_parseTimestamp(r['completed_at'])),
      pointsAwarded: Value((r['points_awarded'] as num?)?.toInt() ?? 0),
      createdAt: Value(_parseTimestamp(r['created_at'])),
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value('synced'),
    );
  }

  DateTime? _parseTimestamp(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();
}
