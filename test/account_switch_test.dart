import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/core/services/workout_push_service.dart';

/// Someone signs out and someone else signs in on the same phone. The sign-in
/// listener (AuthNotifier._ensureLocalProfile) asks
/// `UserProfileDao.heldByOtherAccount` and wipes before the workout backfill
/// runs. Without that, the first person's
/// profile, health answers and workouts stayed on screen for the second, and
/// the backfill uploaded the first person's workouts into the second account.
void main() {
  late AppDatabase db;
  late UserProfileDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = UserProfileDao(db);
  });
  tearDown(() => db.close());

  /// A profile plus one finished, never-pushed workout with a completed set.
  Future<void> seedAccount(String? remoteId) async {
    await dao.upsert(UserProfilesCompanion(
      remoteId: Value(remoteId),
      displayName: const Value('First Bro'),
      bodyWeightKg: const Value(82),
      healthConsentAt: Value(DateTime(2026, 9, 30)),
    ));
    final started = DateTime.utc(2026, 9, 29, 10);
    final sid = await db.into(db.sessions).insert(SessionsCompanion.insert(
          startedAt: started,
          finishedAt: Value(started.add(const Duration(hours: 1))),
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
  }

  test('only a profile linked to another account counts as theirs', () async {
    expect(await dao.heldByOtherAccount('b'), isFalse, reason: 'empty device');

    await seedAccount(null);
    expect(
      await dao.heldByOtherAccount('b'),
      isFalse,
      reason: 'made before any sign-in: it belongs to whoever signs in',
    );

    await db.wipeAccountData();
    await seedAccount('a');
    expect(await dao.heldByOtherAccount('a'), isFalse, reason: 'same account');
    expect(await dao.heldByOtherAccount('b'), isTrue);
  });

  test("after the switch wipe the backfill has nothing of the first account's",
      () async {
    await seedAccount('a');
    final push = WorkoutPushService(db, SyncService(db, null));

    // The same account signing back in still gets its unsent workout pushed.
    await push.pushPending();
    expect(await db.select(db.syncQueue).get(), hasLength(1));

    // A different account: wipe first (as the listener does), then the new
    // account's profile, then the backfill.
    expect(await dao.heldByOtherAccount('b'), isTrue);
    await db.wipeAccountData();
    await dao.upsert(const UserProfilesCompanion(remoteId: Value('b')));
    await push.pushPending();

    expect(await db.select(db.syncQueue).get(), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
    final profile = (await dao.getFirst())!;
    expect(profile.remoteId, 'b');
    expect(profile.displayName, isNull);
    expect(profile.bodyWeightKg, isNull);
    expect(profile.healthConsentAt, isNull);
  });
}
