import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/core/services/workout_push_service.dart';

/// Workout upload path (migration 019): finishing a session must enqueue ONE
/// atomic push_workout RPC item with client-generated uuids persisted
/// locally, and the sign-in backfill must catch never-pushed history — all
/// against a null Supabase client (a real network call would throw).
void main() {
  late AppDatabase db;
  late WorkoutPushService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = WorkoutPushService(db, SyncService(db, null));
  });

  tearDown(() => db.close());

  Future<List<SyncQueueData>> outbox() => db.select(db.syncQueue).get();

  Future<void> seedProfile({String? remoteId = 'auth-uid-1'}) =>
      db.into(db.userProfiles).insert(UserProfilesCompanion(
            displayName: const Value('Bro'),
            remoteId: Value(remoteId),
          ));

  /// A session with two exercises: bench (1 completed + 1 unticked set) and
  /// squat (no completed sets — must not upload).
  Future<int> seedSession({bool finished = true}) async {
    final started = DateTime.utc(2026, 8, 17, 10);
    final sid = await db.into(db.sessions).insert(SessionsCompanion.insert(
          startedAt: started,
          finishedAt: Value(
            finished ? started.add(const Duration(hours: 1)) : null,
          ),
          durationSeconds: const Value(3600),
          totalVolume: const Value(500),
        ));
    final bench = await db.into(db.sessionExercises).insert(
        SessionExercisesCompanion.insert(
            sessionId: sid, exerciseId: 'bench_press', orderIndex: 0));
    await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
          sessionExerciseId: bench,
          setIndex: 0,
          weight: const Value(100),
          reps: const Value(5),
          isCompleted: const Value(true),
        ));
    await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
          sessionExerciseId: bench,
          setIndex: 1,
          weight: const Value(100),
          reps: const Value(5),
        ));
    final squat = await db.into(db.sessionExercises).insert(
        SessionExercisesCompanion.insert(
            sessionId: sid, exerciseId: 'squat', orderIndex: 1));
    await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
          sessionExerciseId: squat,
          setIndex: 0,
        ));
    return sid;
  }

  group('enqueuePush', () {
    test('enqueues one rpc item with uuids persisted on the local rows',
        () async {
      await seedProfile();
      final sid = await seedSession();

      await service.enqueuePush(sid);

      final items = await outbox();
      expect(items, hasLength(1));
      expect(items.single.syncTableName, 'push_workout');
      expect(items.single.operation, 'rpc');

      final payload = jsonDecode(items.single.payload) as Map;
      final session = await db.select(db.sessions).getSingle();
      expect(session.remoteId, isNotNull);
      expect((payload['session'] as Map)['id'], session.remoteId);
      expect((payload['session'] as Map)['total_volume_kg'], 500);

      // Only bench (has a completed set), and only its completed set.
      final exercises = payload['exercises'] as List;
      expect(exercises, hasLength(1));
      final bench = exercises.single as Map;
      expect(bench['exercise_id'], 'bench_press');
      final sets = bench['sets'] as List;
      expect(sets, hasLength(1));
      expect((sets.single as Map)['weight_kg'], 100);
      expect((sets.single as Map)['reps'], 5);

      // The pushed set's uuid landed on the local row too.
      final localSets = await db.select(db.workoutSets).get();
      final completed = localSets.where((s) => s.isCompleted).single;
      expect(completed.remoteId, (sets.single as Map)['id']);
    });

    test('re-push reuses the same uuids (server-side idempotency)', () async {
      await seedProfile();
      final sid = await seedSession();
      await service.enqueuePush(sid);
      await service.enqueuePush(sid);

      final items = await outbox();
      expect(items, hasLength(2));
      final p1 = jsonDecode(items.first.payload) as Map;
      final p2 = jsonDecode(items.last.payload) as Map;
      expect((p1['session'] as Map)['id'], (p2['session'] as Map)['id']);
      expect(
        ((p1['exercises'] as List).single as Map)['id'],
        ((p2['exercises'] as List).single as Map)['id'],
      );
    });

    test('skips unfinished sessions and unsynced profiles', () async {
      await seedProfile(remoteId: null);
      final sid = await seedSession();
      await service.enqueuePush(sid);
      expect(await outbox(), isEmpty);

      await db.delete(db.userProfiles).go();
      await seedProfile();
      final unfinished = await seedSession(finished: false);
      await service.enqueuePush(unfinished);
      expect(await outbox(), isEmpty);
    });
  });

  group('concurrency (the reviewed double-push bug)', () {
    test('concurrent enqueuePush yields ONE session uuid across items',
        () async {
      await seedProfile();
      final sid = await seedSession();

      await Future.wait([service.enqueuePush(sid), service.enqueuePush(sid)]);

      final items = await outbox();
      final sessionIds = {
        for (final i in items)
          ((jsonDecode(i.payload) as Map)['session'] as Map)['id'],
      };
      // Both items (if two) must carry the SAME uuid — the atomic claim
      // makes the loser reuse the winner's id, so the server upserts one
      // session instead of inserting a duplicate tree.
      expect(sessionIds, hasLength(1));
      final session = await db.select(db.sessions).getSingle();
      expect(sessionIds.single, session.remoteId);
    });

    test('concurrent pushPending scans do not double-enqueue', () async {
      await seedProfile();
      for (var i = 0; i < 3; i++) {
        await seedSession();
      }

      await Future.wait([service.pushPending(), service.pushPending()]);

      // One item per session: the losing scan skips claimed sessions.
      expect(await outbox(), hasLength(3));
    });
  });

  group('pushPending', () {
    test('backfills only never-pushed finished sessions, then goes quiet',
        () async {
      await seedProfile();
      await seedSession();
      await seedSession(finished: false);
      final pushed = await seedSession();
      await (db.update(db.sessions)
            ..where((t) => t.localId.equals(pushed)))
          .write(const SessionsCompanion(remoteId: Value('already-up')));

      await service.pushPending();
      expect(await outbox(), hasLength(1));

      // Rescan: everything now carries a remoteId — nothing new enqueued.
      await service.pushPending();
      expect(await outbox(), hasLength(1));
    });
  });
}
