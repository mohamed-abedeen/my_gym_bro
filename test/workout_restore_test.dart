import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/database/app_database.dart' hide Session;
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/core/services/workout_restore_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockHistorySource extends Mock implements WorkoutHistorySource {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

const _uid = 'auth-uid-1';

/// Gap 2 — restore. After delete + reinstall the local DB is empty while the
/// history sits in Supabase (pushed by `push_workout`, migration 019). Signing
/// in must pull it back, once, safely, and without ever touching a device
/// that already has workouts.
void main() {
  late AppDatabase db;
  late _MockHistorySource source;
  late WorkoutRestoreService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    source = _MockHistorySource();
    service = WorkoutRestoreService(db, source);
  });
  tearDown(() => db.close());

  Future<void> seedProfile({String? remoteId = _uid}) =>
      db.into(db.userProfiles).insert(
            UserProfilesCompanion(remoteId: Value(remoteId)),
          );

  /// A server session as PostgREST returns it with nested children.
  Map<String, dynamic> serverSession(
    String id, {
    String startedAt = '2026-09-29T10:00:00+00:00',
    String? finishedAt = '2026-09-29T11:00:00+00:00',
    List<Map<String, dynamic>>? exercises,
  }) =>
      {
        'id': id,
        'started_at': startedAt,
        'finished_at': finishedAt,
        'duration_seconds': 3600,
        'total_volume_kg': 500.0,
        'notes': 'felt strong',
        'session_exercises': exercises ??
            [
              {
                'id': '$id-ex2',
                'exercise_id': 'squat',
                'order_index': 1,
                'deleted_at': null,
                'sets': [
                  {
                    'id': '$id-ex2-s0',
                    'set_index': 0,
                    'weight_kg': 140,
                    'reps': 3,
                    'is_warmup': false,
                    'is_dropset': false,
                    'rpe': 8.0,
                    'completed_at': '2026-09-29T10:40:00+00:00',
                    'deleted_at': null,
                  },
                ],
              },
              {
                'id': '$id-ex1',
                'exercise_id': 'bench_press',
                'order_index': 0,
                'deleted_at': null,
                'sets': [
                  {
                    'id': '$id-ex1-s1',
                    'set_index': 1,
                    'weight_kg': 100.0,
                    'reps': 5,
                    'is_warmup': false,
                    'is_dropset': true,
                    'rpe': null,
                    'completed_at': '2026-09-29T10:20:00+00:00',
                    'deleted_at': null,
                  },
                  {
                    'id': '$id-ex1-s0',
                    'set_index': 0,
                    'weight_kg': 60.0,
                    'reps': 8,
                    'is_warmup': true,
                    'is_dropset': false,
                    'rpe': null,
                    'completed_at': '2026-09-29T10:10:00+00:00',
                    'deleted_at': null,
                  },
                  {
                    'id': '$id-ex1-gone',
                    'set_index': 2,
                    'weight_kg': 100.0,
                    'reps': 5,
                    'deleted_at': '2026-09-30T00:00:00+00:00',
                  },
                ],
              },
              {
                'id': '$id-deleted',
                'exercise_id': 'curl',
                'order_index': 2,
                'deleted_at': '2026-09-30T00:00:00+00:00',
                'sets': <Map<String, dynamic>>[],
              },
            ],
      };

  void serve(List<List<Map<String, dynamic>>> pages) {
    when(() => source.fetchSessionPage(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((inv) async {
      final offset = inv.namedArguments[#offset] as int;
      final index = offset ~/ WorkoutRestoreService.pageSize;
      return index < pages.length ? pages[index] : <Map<String, dynamic>>[];
    });
  }

  group('WorkoutRestoreService.restoreIfEmpty', () {
    test('rebuilds sessions, exercises and sets with their server ids',
        () async {
      await seedProfile();
      serve([
        [serverSession('s1')],
      ]);

      expect(await service.restoreIfEmpty(_uid), 1);

      final session = (await db.select(db.sessions).get()).single;
      expect(session.remoteId, 's1');
      expect(session.syncStatus, 'synced');
      expect(session.startedAt.toUtc(), DateTime.utc(2026, 9, 29, 10));
      expect(session.finishedAt!.toUtc(), DateTime.utc(2026, 9, 29, 11));
      expect(session.durationSeconds, 3600);
      expect(session.totalVolume, 500);
      expect(session.notes, 'felt strong');

      final exercises = await (db.select(db.sessionExercises)
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
      expect([for (final e in exercises) e.exerciseId], ['bench_press', 'squat'],
          reason: 'soft-deleted exercise is not restored');
      expect([for (final e in exercises) e.remoteId], ['s1-ex1', 's1-ex2']);
      expect(exercises.every((e) => e.sessionId == session.localId), isTrue);

      final bench = exercises.first;
      final sets = await (db.select(db.workoutSets)
            ..where((t) => t.sessionExerciseId.equals(bench.localId))
            ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
          .get();
      expect([for (final s in sets) s.remoteId], ['s1-ex1-s0', 's1-ex1-s1'],
          reason: 'soft-deleted set is not restored');
      expect(sets.first.isWarmup, isTrue);
      expect(sets.first.weight, 60);
      expect(sets.first.reps, 8);
      expect(sets.last.isDropset, isTrue);
      expect(sets.every((s) => s.isCompleted), isTrue);

      final squatSet = (await db.select(db.workoutSets).get())
          .firstWhere((s) => s.remoteId == 's1-ex2-s0');
      expect(squatSet.weight, 140, reason: 'int JSON number is accepted');
      expect(squatSet.rpe, 8);
    });

    test('restored history is not re-uploaded by the sign-in backfill',
        () async {
      await seedProfile();
      serve([
        [serverSession('s1')],
      ]);
      await service.restoreIfEmpty(_uid);

      final unsent = await (db.select(db.sessions)
            ..where((t) => t.remoteId.isNull()))
          .get();
      expect(unsent, isEmpty);
    });

    test('pages through the whole history', () async {
      await seedProfile();
      final full = [
        for (var i = 0; i < WorkoutRestoreService.pageSize; i++)
          serverSession('a$i', exercises: const []),
      ];
      serve([
        full,
        [serverSession('b0', exercises: const [])],
      ]);

      expect(await service.restoreIfEmpty(_uid),
          WorkoutRestoreService.pageSize + 1);
      verify(() => source.fetchSessionPage(
            offset: WorkoutRestoreService.pageSize,
            limit: WorkoutRestoreService.pageSize,
          )).called(1);
    });

    test('skips unfinished, malformed and duplicate server rows', () async {
      await seedProfile();
      serve([
        [
          serverSession('open', finishedAt: null),
          serverSession('ok', exercises: const []),
          serverSession('ok', exercises: const []),
          {'id': null, 'started_at': '2026-09-29T10:00:00Z'},
        ],
      ]);

      expect(await service.restoreIfEmpty(_uid), 1);
      expect(
        [for (final s in await db.select(db.sessions).get()) s.remoteId],
        ['ok'],
      );
    });

    test('does nothing when the device already has workouts', () async {
      await seedProfile();
      await db.into(db.sessions).insert(
          SessionsCompanion.insert(startedAt: DateTime.utc(2026, 10)));
      serve([
        [serverSession('s1')],
      ]);

      expect(await service.restoreIfEmpty(_uid), 0);
      verifyNever(() => source.fetchSessionPage(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          ));
      expect(await db.select(db.sessions).get(), hasLength(1));
    });

    test('is idempotent: a second run writes nothing', () async {
      await seedProfile();
      serve([
        [serverSession('s1')],
      ]);
      expect(await service.restoreIfEmpty(_uid), 1);
      expect(await service.restoreIfEmpty(_uid), 0);
      expect(await db.select(db.sessions).get(), hasLength(1));
      expect(await db.select(db.sessionExercises).get(), hasLength(2));
    });

    test('offline: writes nothing and a later run retries', () async {
      await seedProfile();
      when(() => source.fetchSessionPage(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenThrow(Exception('SocketException: offline'));

      expect(await service.restoreIfEmpty(_uid), 0);
      expect(await db.select(db.sessions).get(), isEmpty);

      serve([
        [serverSession('s1')],
      ]);
      expect(await service.restoreIfEmpty(_uid), 1);
    });

    test('a failure on a later page leaves the DB empty (all or nothing)',
        () async {
      await seedProfile();
      final full = [
        for (var i = 0; i < WorkoutRestoreService.pageSize; i++)
          serverSession('a$i', exercises: const []),
      ];
      when(() => source.fetchSessionPage(
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((inv) async {
        if ((inv.namedArguments[#offset] as int) == 0) return full;
        throw Exception('timeout');
      });

      expect(await service.restoreIfEmpty(_uid), 0);
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('never restores into another account or a signed-out device',
        () async {
      serve([
        [serverSession('s1')],
      ]);

      expect(await service.restoreIfEmpty(_uid), 0, reason: 'no profile');

      await seedProfile(remoteId: 'someone-else');
      expect(await service.restoreIfEmpty(_uid), 0, reason: 'other account');
      await db.delete(db.userProfiles).go();
      await seedProfile(remoteId: null);
      expect(await service.restoreIfEmpty(_uid), 0, reason: 'unclaimed');

      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('no source (Supabase not configured) is a no-op', () async {
      await seedProfile();
      expect(await WorkoutRestoreService(db, null).restoreIfEmpty(_uid), 0);
    });
  });

  group('sign-in through AuthNotifier after a reinstall', () {
    test('an empty device with a signed-in account gets its history back',
        () async {
      final supabase = _MockSupabaseClient();
      final goTrue = _MockGoTrueClient();
      final authEvents = StreamController<AuthState>.broadcast();
      when(() => supabase.auth).thenReturn(goTrue);
      when(() => goTrue.onAuthStateChange)
          .thenAnswer((_) => authEvents.stream);
      // Profile pull offline → local defaults, as on a flaky first launch.
      when(() => supabase.from(any())).thenThrow(Exception('offline'));
      serve([
        [serverSession('s1')],
      ]);
      final notifier = AuthNotifier(
        db,
        supabase,
        SyncService(db, null),
        historySource: source,
      );
      addTearDown(() async {
        notifier.dispose();
        await authEvents.close();
      });

      // iOS keeps the Keychain session across a reinstall, so the app starts
      // already signed in: an initialSession event on an empty database.
      authEvents.add(AuthState(
        AuthChangeEvent.initialSession,
        Session(
          accessToken: 't',
          tokenType: 'bearer',
          user: const User(
            id: _uid,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-01T00:00:00Z',
            email: 'bro@example.com',
          ),
        ),
      ));
      await pumpEventQueue(times: 300);

      expect(notifier.state.status, AuthStatus.authenticated);
      final sessions = await db.select(db.sessions).get();
      expect(sessions.map((s) => s.remoteId), ['s1']);
      expect(await db.select(db.syncQueue).get(), isEmpty,
          reason: 'restored history must not be pushed back');
    });
  });
}
