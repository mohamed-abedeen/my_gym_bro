import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';

/// `AppDatabase.wipeAccountData` is the local half of account deletion: the
/// next sign-up on this device must not inherit (or backfill-push) the deleted
/// user's history, while the device-level exercise catalogue stays.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seed() async {
    await db.into(db.userProfiles).insert(
          const UserProfilesCompanion(
            remoteId: Value('user-1'),
            displayName: Value('Bro'),
          ),
        );
    await db.into(db.exercises).insert(
          const ExercisesCompanion(
            exerciseId: Value('catalogue-1'),
            name: Value('Bench Press'),
          ),
        );
    await db.into(db.exercises).insert(
          const ExercisesCompanion(
            exerciseId: Value('custom-1'),
            name: Value('My Move'),
            isCustom: Value(true),
          ),
        );
    await db.into(db.schedules).insert(
          const SchedulesCompanion(name: Value('PPL'), isActive: Value(true)),
        );
    await db.into(db.sessions).insert(
          SessionsCompanion(startedAt: Value(DateTime(2026, 9, 1, 7))),
        );
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion(
            syncTableName: const Value('sessions'),
            rowId: const Value(1),
            operation: const Value('insert'),
            payload: const Value('{}'),
            createdAt: Value(DateTime(2026, 9, 1, 8)),
          ),
        );
  }

  test('wipes every account row and keeps the exercise catalogue', () async {
    await seed();

    await db.wipeAccountData();

    expect(await db.select(db.userProfiles).get(), isEmpty);
    expect(await db.select(db.schedules).get(), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);

    final remaining = await db.select(db.exercises).get();
    expect(remaining.map((e) => e.exerciseId), ['catalogue-1']);
    expect(remaining.single.isCustom, isFalse);
  });

  test('is safe to run on an empty database and to repeat', () async {
    await db.wipeAccountData();
    await seed();
    await db.wipeAccountData();
    await db.wipeAccountData();

    expect(await db.select(db.sessions).get(), isEmpty);
    expect((await db.select(db.exercises).get()).length, 1);
  });
}
