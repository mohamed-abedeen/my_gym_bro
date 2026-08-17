import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/challenge_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/leaderboard/challenge_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

const _me = 'me-uid';
const _other = 'other-uid';

/// Offline-first challenge flows: every mutation must land in the local Drift
/// cache AND the sync outbox without touching the network. The mocked
/// Supabase client only serves `auth.currentUser.id`; SyncService gets a null
/// client, so a test would throw if any flow tried a real network call.
void main() {
  late AppDatabase db;
  late ChallengeDao dao;
  late ChallengeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = ChallengeDao(db);
    final supabase = _MockSupabaseClient();
    final auth = _MockGoTrueClient();
    final user = _MockUser();
    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.id).thenReturn(_me);
    repo = ChallengeRepository(
      challengeDao: dao,
      syncService: SyncService(db, null),
      supabase: supabase,
    );
  });

  tearDown(() => db.close());

  Future<List<SyncQueueData>> outbox() => db.select(db.syncQueue).get();
  Future<void> clearOutbox() => db.delete(db.syncQueue).go();

  Future<Challenge> seedChallenge({
    String remoteId = 'c1',
    String source = 'curated',
    String? creatorId,
    String goalType = 'volume',
    double goalValue = 1000,
    DateTime? startsAt,
    DateTime? endsAt,
    int points = 25,
    String status = 'active',
    String syncStatus = 'synced',
  }) async {
    final now = DateTime.now();
    await dao.upsertChallenge(
      ChallengesCompanion.insert(
        source: source,
        title: 'Test challenge',
        goalType: goalType,
        goalValue: goalValue,
        startsAt: startsAt ?? now.subtract(const Duration(hours: 1)),
        endsAt: endsAt ?? now.add(const Duration(hours: 23)),
        remoteId: Value(remoteId),
        creatorId: Value(creatorId),
        points: Value(points),
        status: Value(status),
        syncStatus: Value(syncStatus),
        updatedAt: Value(now),
      ),
    );
    return (await dao.findByRemoteId(remoteId))!;
  }

  /// One finished session with [sets] completed working sets of
  /// weight × reps, started at [startedAt].
  Future<void> seedWorkout({
    required DateTime startedAt,
    double weight = 100,
    int reps = 5,
    int sets = 1,
  }) async {
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            startedAt: startedAt,
            finishedAt: Value(startedAt.add(const Duration(hours: 1))),
          ),
        );
    final seId = await db.into(db.sessionExercises).insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: 'ex1',
            orderIndex: 0,
          ),
        );
    for (var i = 0; i < sets; i++) {
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              sessionExerciseId: seId,
              setIndex: i,
              weight: Value(weight),
              reps: Value(reps),
              isCompleted: const Value(true),
            ),
          );
    }
  }

  group('join', () {
    test('writes participation locally and queues the insert', () async {
      final challenge = await seedChallenge();
      expect(await repo.join(challenge), JoinChallengeResult.joined);

      final row = await dao.findParticipation('c1', _me);
      expect(row, isNotNull);
      expect(row!.progress, 0);
      expect(row.completedAt, isNull);
      expect(row.remoteId, isNotNull);
      expect(row.syncStatus, 'pending');

      final items = await outbox();
      expect(items, hasLength(1));
      expect(items.single.syncTableName, 'challenge_participants');
      expect(items.single.operation, 'insert');
      final payload = jsonDecode(items.single.payload) as Map<String, dynamic>;
      expect(payload['challenge_id'], 'c1');
      expect(payload['user_id'], _me);
      expect(payload['id'], row.remoteId);
      // points_awarded is server-computed — never sent.
      expect(payload.containsKey('points_awarded'), isFalse);
    });

    test('is refused when already joined, and queues nothing', () async {
      final challenge = await seedChallenge();
      await repo.join(challenge);
      await clearOutbox();

      expect(await repo.join(challenge), JoinChallengeResult.alreadyJoined);
      expect(await outbox(), isEmpty);
    });

    test('is refused when the window is over', () async {
      final challenge = await seedChallenge(
        startsAt: DateTime.now().subtract(const Duration(days: 2)),
        endsAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(await repo.join(challenge), JoinChallengeResult.unavailable);
      expect(await outbox(), isEmpty);
    });

    test('counts window work at join and completes when goal already met',
        () async {
      // 3 × 100 kg × 5 = 1,500 kg inside the window; goal is 1,000.
      await seedWorkout(startedAt: DateTime.now(), sets: 3);
      final challenge = await seedChallenge();

      expect(await repo.join(challenge), JoinChallengeResult.joined);

      final row = await dao.findParticipation('c1', _me);
      expect(row!.progress, 1500);
      expect(row.completedAt, isNotNull);
      final payload = jsonDecode((await outbox()).single.payload)
          as Map<String, dynamic>;
      expect(payload['completed_at'], isNotNull);
    });
  });

  group('create', () {
    test('writes the challenge locally and queues the insert', () async {
      final result = await repo.create(
        title: 'Squat marathon',
        goalType: 'sessions',
        goalValue: 5,
        points: 30,
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(days: 7)),
      );
      expect(result, CreateChallengeResult.created);

      final rows = await dao.watchAll().first;
      expect(rows, hasLength(1));
      expect(rows.single.source, 'community');
      expect(rows.single.creatorId, _me);
      expect(rows.single.syncStatus, 'pending');

      final payload = jsonDecode((await outbox()).single.payload)
          as Map<String, dynamic>;
      expect(payload['source'], 'community');
      expect(payload['creator_id'], _me);
      expect(payload['status'], 'active');
      expect(payload['points'], 30);
    });

    test('rejects everything the server RLS would reject', () async {
      final now = DateTime.now();
      final cases = <Future<CreateChallengeResult>>[
        // Empty title.
        repo.create(
          title: '   ',
          goalType: 'sessions',
          goalValue: 5,
          points: 10,
          startsAt: now,
          endsAt: now.add(const Duration(days: 7)),
        ),
        // Points above the community cap.
        repo.create(
          title: 'x',
          goalType: 'sessions',
          goalValue: 5,
          points: kCommunityChallengeMaxPoints + 1,
          startsAt: now,
          endsAt: now.add(const Duration(days: 7)),
        ),
        // Goal below the server floor (free completion).
        repo.create(
          title: 'x',
          goalType: 'volume',
          goalValue: 0.5,
          points: 10,
          startsAt: now,
          endsAt: now.add(const Duration(days: 7)),
        ),
        // Zero-length window.
        repo.create(
          title: 'x',
          goalType: 'sessions',
          goalValue: 5,
          points: 10,
          startsAt: now,
          endsAt: now,
        ),
        // Window longer than 31 days (would pass a whole-days check).
        repo.create(
          title: 'x',
          goalType: 'sessions',
          goalValue: 5,
          points: 10,
          startsAt: now,
          endsAt: now.add(const Duration(days: 31, hours: 3)),
        ),
        // Back-dated start beyond the sync margin.
        repo.create(
          title: 'x',
          goalType: 'sessions',
          goalValue: 5,
          points: 10,
          startsAt: now.subtract(const Duration(days: 2)),
          endsAt: now.add(const Duration(days: 7)),
        ),
      ];
      for (final c in cases) {
        expect(await c, CreateChallengeResult.invalid);
      }
      expect(await outbox(), isEmpty);
      expect(await dao.watchAll().first, isEmpty);
    });
  });

  group('recomputeProgress', () {
    test('updates progress and completes inside the window', () async {
      final challenge = await seedChallenge(); // goal 1,000 kg
      await repo.join(challenge);
      await clearOutbox();

      await seedWorkout(startedAt: DateTime.now()); // 500 kg
      await repo.recomputeProgress();

      var row = await dao.findParticipation('c1', _me);
      expect(row!.progress, 500);
      expect(row.completedAt, isNull);
      var payload = jsonDecode((await outbox()).single.payload)
          as Map<String, dynamic>;
      expect(payload['progress'], 500);
      expect(payload.containsKey('completed_at'), isFalse);
      await clearOutbox();

      await seedWorkout(startedAt: DateTime.now(), sets: 2); // +1,000 kg
      await repo.recomputeProgress();

      row = await dao.findParticipation('c1', _me);
      expect(row!.progress, 1500);
      expect(row.completedAt, isNotNull);
      payload = jsonDecode((await outbox()).single.payload)
          as Map<String, dynamic>;
      expect(payload['completed_at'], isNotNull);
    });

    test('never stamps a completion discovered after the window closed',
        () async {
      final start = DateTime.now().subtract(const Duration(days: 2));
      final end = DateTime.now().subtract(const Duration(hours: 2));
      await seedChallenge(startsAt: start, endsAt: end);
      // Participation created while the window was open (inserted directly —
      // join() would refuse now).
      await dao.upsertParticipation(
        ChallengeParticipantsCompanion.insert(
          challengeRemoteId: 'c1',
          userId: _me,
          remoteId: const Value('p1'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // Enough volume, logged inside the window — but we only noticed now.
      await seedWorkout(
        startedAt: DateTime.now().subtract(const Duration(hours: 12)),
        sets: 3,
      );

      await repo.recomputeProgress();

      final row = await dao.findParticipation('c1', _me);
      expect(row!.progress, 1500);
      expect(row.completedAt, isNull);
    });
  });

  group('markCustomComplete', () {
    test('completes a custom challenge and queues the update', () async {
      final challenge = await seedChallenge(goalType: 'custom', goalValue: 1);
      await repo.join(challenge);
      await clearOutbox();
      final row = (await dao.findParticipation('c1', _me))!;

      await repo.markCustomComplete(challenge, row);

      final updated = await dao.findParticipation('c1', _me);
      expect(updated!.completedAt, isNotNull);
      expect(updated.progress, 1);
      expect((await outbox()).single.operation, 'update');
    });

    test('refuses non-custom goal types', () async {
      final challenge = await seedChallenge();
      await repo.join(challenge);
      await clearOutbox();
      final row = (await dao.findParticipation('c1', _me))!;

      await repo.markCustomComplete(challenge, row);

      expect((await dao.findParticipation('c1', _me))!.completedAt, isNull);
      expect(await outbox(), isEmpty);
    });
  });

  group('report', () {
    test('queues once and dedupes repeats in the same session', () async {
      final challenge = await seedChallenge(
        remoteId: 'c2',
        source: 'community',
        creatorId: _other,
      );
      await repo.report(challenge, 'spam');
      await repo.report(challenge, 'spam');

      final items = await outbox();
      expect(items, hasLength(1));
      final payload = jsonDecode(items.single.payload) as Map<String, dynamic>;
      expect(payload['challenge_id'], 'c2');
      expect(payload['reporter_id'], _me);
      expect(payload['reason'], 'spam');
    });

    test('curated challenges are not reportable', () async {
      final challenge = await seedChallenge();
      await repo.report(challenge, 'spam');
      expect(await outbox(), isEmpty);
    });
  });

  group('leave / deleteOwn', () {
    test('leave removes the row locally and queues the remote delete',
        () async {
      final challenge = await seedChallenge();
      await repo.join(challenge);
      await clearOutbox();
      final row = (await dao.findParticipation('c1', _me))!;

      await repo.leave(row);

      expect(await dao.findParticipation('c1', _me), isNull);
      final item = (await outbox()).single;
      expect(item.operation, 'delete');
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;
      expect(payload['remote_id'], row.remoteId);
    });

    test('deleteOwn only works on my own community challenge', () async {
      final theirs = await seedChallenge(
        remoteId: 'c2',
        source: 'community',
        creatorId: _other,
      );
      await repo.deleteOwn(theirs);
      expect(await dao.findByRemoteId('c2'), isNotNull);
      expect(await outbox(), isEmpty);

      final mine = await seedChallenge(
        remoteId: 'c3',
        source: 'community',
        creatorId: _me,
      );
      await repo.deleteOwn(mine);
      expect(await dao.findByRemoteId('c3'), isNull);
      expect((await outbox()).single.operation, 'delete');
    });
  });

  group('server snapshot reconciliation', () {
    test('server row overwrites a pushed-but-pending local row (points land)',
        () async {
      final challenge = await seedChallenge();
      await repo.join(challenge);
      final local = (await dao.findParticipation('c1', _me))!;
      expect(local.syncStatus, 'pending');
      expect(local.pointsAwarded, 0);

      // The server's copy of the same row, after the award trigger ran.
      await dao.replaceParticipationFromServer(_me, [
        ChallengeParticipantsCompanion.insert(
          challengeRemoteId: 'c1',
          userId: _me,
          remoteId: Value(local.remoteId),
          progress: const Value(1000),
          completedAt: Value(DateTime.now()),
          pointsAwarded: const Value(25),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value('synced'),
        ),
      ]);

      final rows = await dao.watchParticipation(_me).first;
      expect(rows, hasLength(1));
      expect(rows.single.syncStatus, 'synced');
      expect(rows.single.pointsAwarded, 25);
      expect(rows.single.completedAt, isNotNull);
    });

    test('upsertParticipation conflict-resolves on (challenge, user)',
        () async {
      await dao.upsertParticipation(
        ChallengeParticipantsCompanion.insert(
          challengeRemoteId: 'c1',
          userId: _me,
          remoteId: const Value('p1'),
          progress: const Value(10),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // Same unique key again — must update, not throw.
      await dao.upsertParticipation(
        ChallengeParticipantsCompanion.insert(
          challengeRemoteId: 'c1',
          userId: _me,
          remoteId: const Value('p1'),
          progress: const Value(20),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final rows = await dao.watchParticipation(_me).first;
      expect(rows, hasLength(1));
      expect(rows.single.progress, 20);
    });

    test('stale pending rows the server rejected are purged, fresh kept',
        () async {
      final now = DateTime.now();
      await dao.upsertParticipation(
        ChallengeParticipantsCompanion.insert(
          challengeRemoteId: 'c-old',
          userId: _me,
          remoteId: const Value('p-old'),
          updatedAt: Value(now.subtract(const Duration(hours: 25))),
        ),
      );
      await dao.upsertParticipation(
        ChallengeParticipantsCompanion.insert(
          challengeRemoteId: 'c-new',
          userId: _me,
          remoteId: const Value('p-new'),
          updatedAt: Value(now),
        ),
      );

      await dao.replaceParticipationFromServer(_me, const []);

      final rows = await dao.watchParticipation(_me).first;
      expect(rows, hasLength(1));
      expect(rows.single.challengeRemoteId, 'c-new');
    });

    test('server status flips land on a pending locally-created challenge',
        () async {
      await seedChallenge(
        remoteId: 'c9',
        source: 'community',
        creatorId: _me,
        syncStatus: 'pending',
      );
      await dao.replaceChallengesFromServer([
        ChallengesCompanion.insert(
          source: 'community',
          title: 'Test challenge',
          goalType: 'volume',
          goalValue: 1000,
          startsAt: DateTime.now().subtract(const Duration(days: 1)),
          endsAt: DateTime.now().add(const Duration(days: 1)),
          remoteId: const Value('c9'),
          creatorId: const Value(_me),
          status: const Value('hidden'),
          syncStatus: const Value('synced'),
          updatedAt: Value(DateTime.now()),
        ),
      ]);

      // Hidden rows are filtered from the visible stream…
      expect(await dao.watchAll().first, isEmpty);
      // …but the row itself reconciled to the server's status.
      final row = await dao.findByRemoteId('c9');
      expect(row!.status, 'hidden');
      expect(row.syncStatus, 'synced');
    });
  });
}
